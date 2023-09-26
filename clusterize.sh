################################################################################################# clusterize #########################################################################################
my_ip=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r '.network.interface[0].ipv4.ipAddress[0].privateIpAddress')

VMS=( ${vm_names} )
VMS+=($HOSTNAME)
IPS=( ${private_ips} )
IPS+=($my_ip)
CLUSTER_NAME=${cluster_name}
HOSTS_NUM=${cluster_size}
NVMES_NUM=${nvmes_num}
STRIPE_WIDTH=${stripe_width}
PROTECTION_LEVEL=${protection_level}
HOTSPARE=${hotspare}
INSTALL_DPDK=${install_dpdk}
SMBW_ENABLED=${smbw_enabled}
SET_OBS=${set_obs}
ADD_FRONTEND=${add_frontend}

CONTAINER_NAMES=(drives0 compute0)
PORTS=(14000 15000)

if [[ $ADD_FRONTEND == true ]]; then
  CONTAINER_NAMES+=(frontend0)
  PORTS+=(16000)
fi

HOST_IPS=()
HOST_NAMES=()
for i in "$${!IPS[@]}"; do
	for j in "$${!PORTS[@]}"; do
		HOST_IPS+=($(echo "$${IPS[i]}:$${PORTS[j]}"))
		HOST_NAMES+=($(echo "$${VMS[i]}-$${CONTAINER_NAMES[j]}"))
	done
done
host_ips=$(IFS=, ;echo "$${HOST_IPS[*]}")
host_names=$(IFS=' ' ;echo "$${HOST_NAMES[*]}")

echo "$(date -u): start clusterization"

vms_string=$(printf "%s "  "$${VMS[@]}" | rev | cut -c2- | rev)
while ! weka cluster create $host_names --host-ips $host_ips
do
    sleep 10
done

if [[ $INSTALL_DPDK == true ]]; then
	
weka debug override add --key allow_uncomputed_backend_checksum
weka debug override add --key allow_azure_auto_detection

fi

sleep 30s
echo "$(date -u): adding drives"

DRIVE_NUMS=( $(weka cluster container | grep drives | awk '{print $1;}') )

for drive_num in "$${DRIVE_NUMS[@]}"; do
  for (( d=0; d<$NVMES_NUM; d++ )); do
    while ! lsblk "/dev/nvme$d"n1 >/dev/null 2>&1 ; do
      echo "waiting for nvme$dn1 to be ready"
      sleep 5
    done
    weka cluster drive add "$drive_num" "/dev/nvme$d"n1
  done
done

weka cluster update --cluster-name="$CLUSTER_NAME"

weka cloud enable || true # skipping required for private network

if [ "$STRIPE_WIDTH" -gt 0 ] && [ "$PROTECTION_LEVEL" -gt 0 ]; then
	weka cluster update --data-drives $STRIPE_WIDTH --parity-drives $PROTECTION_LEVEL
fi
weka cluster hot-spare $HOTSPARE
weka cluster start-io

sleep 15s
echo "$(date -u): after start-io"

weka cluster process
weka cluster drive
weka cluster container

weka fs group create default
# for SMBW setup we need to create a separate fs with 10GB capacity
if [[ $SMBW_ENABLED == true ]]; then
  weka fs create .config_fs default 10GB
fi
full_capacity=$(weka status -J | jq .capacity.unprovisioned_bytes)
weka fs create default default "$full_capacity"B

if [[ ${set_obs} == true ]]; then
  TIERING_SSD_PERCENT=${tiering_ssd_percent}
  OBS_NAME=${obs_name}
  OBS_CONTAINER_NAME=${obs_container_name}
  OBS_BLOB_KEY=${blob_obs_access_key}

  weka fs tier s3 add azure-obs --site local --obs-name default-local --obs-type AZURE --hostname $OBS_NAME.blob.core.windows.net --port 443 --bucket $OBS_CONTAINER_NAME --access-key-id $OBS_NAME --secret-key $OBS_BLOB_KEY --protocol https --auth-method AWSSignature4
  weka fs tier s3 attach default azure-obs
  tiering_percent=$(echo "$full_capacity * 100 / $TIERING_SSD_PERCENT" | bc)
  weka fs update default --total-capacity "$tiering_percent"B
fi

if [[ $INSTALL_DPDK == true ]]; then
	weka alerts mute NodeRDMANotActive 365d
else
	weka alerts mute JumboConnectivity 365d
	weka alerts mute UdpModePerformanceWarning 365d
fi

echo "$(date -u): clusterization complete"
echo "completed successfully" > /tmp/weka_clusterization_completion_validation
