#!/bin/bash
set -ex

while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   sleep 2
done
apt install net-tools -y

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH

# install ofed
if [[ ${install_ofed} == true ]]; then
  OFED_NAME=ofed-${ofed_version}
  if [[ "${install_ofed_url}" ]]; then
    wget ${install_ofed_url} -O $INSTALLATION_PATH/$OFED_NAME.tgz
  else
    wget http://content.mellanox.com/ofed/MLNX_OFED-${ofed_version}/MLNX_OFED_LINUX-${ofed_version}-ubuntu20.04-x86_64.tgz -O $INSTALLATION_PATH/$OFED_NAME.tgz
  fi

  tar xf $INSTALLATION_PATH/$OFED_NAME.tgz --directory $INSTALLATION_PATH --one-top-level=$OFED_NAME
  cd $INSTALLATION_PATH/$OFED_NAME/*/
  ./mlnxofedinstall --without-fw-update --add-kernel-support --force 2>&1 | tee /tmp/weka_ofed_installation
  /etc/init.d/openibd restart

fi

for(( i=0; i<${nics_num}; i++ )); do
    cat <<-EOF | sed -i "/        eth$i/r /dev/stdin" /etc/netplan/50-cloud-init.yaml
            mtu: 3900
EOF
done

# config network with multi nics
if [[ ${install_cluster_dpdk} == true ]]; then
  for(( i=0; i<${nics_num}; i++)); do
    echo "20$i eth$i-rt" >> /etc/iproute2/rt_tables
  done

  echo "network:"> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
  echo "  config: disabled" >> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
  gateway=$(ip r | grep default | awk '{print $3}')
  for(( i=0; i<${nics_num}; i++ )); do
    eth=$(ifconfig | grep eth$i -C2 | grep 'inet ' | awk '{print $2}')
    cat <<-EOF | sed -i "/            set-name: eth$i/r /dev/stdin" /etc/netplan/50-cloud-init.yaml
            routes:
             - to: ${subnet_range}
               via: $gateway
               metric: 200
               table: 20$i
             - to: 0.0.0.0/0
               via: $gateway
               table: 20$i
            routing-policy:
             - from: $eth/32
               table: 20$i
             - to: $eth/32
               table: 20$i
EOF
  done
fi

netplan apply

apt update -y
apt install -y jq

# attache disk
wekaiosw_device=/dev/"$(lsblk | grep ${disk_size}G | awk '{print $1}')"

status=0
mkfs.ext4 -L wekaiosw $wekaiosw_device
mkdir -p /opt/weka 2>&1
mount $wekaiosw_device /opt/weka

echo "LABEL=wekaiosw /opt/weka ext4 defaults 0 2" >>/etc/fstab

rm -rf $INSTALLATION_PATH


###########################################################################################################################################################################################################


FAILURE_DOMAIN=$(printf $(hostname -I) | sha256sum | tr -d '-' | cut -c1-16)
COMPUTE_MEMORY=${memory}
NUM_COMPUTE_CONTAINERS=${compute_num}
NUM_FRONTEND_CONTAINERS=${frontend_num}
NUM_DRIVE_CONTAINERS=${drive_num}
NICS_NUM=${nics_num}
INSTALL_DPDK=${install_cluster_dpdk}
SUBNETS="${all_subnets}"
SUBNET_PREFIXES=( "${subnet_prefixes}" )
GATEWAYS=""
for subnet in $${SUBNET_PREFIXES[@]}
do
	gateway=$(python3 -c "import ipaddress;import sys;n = ipaddress.IPv4Network(sys.argv[1]);sys.stdout.write(n[1].compressed)" "$subnet")
	GATEWAYS="$GATEWAYS $gateway"
done
GATEWAYS=$(echo "$GATEWAYS" | sed 's/ //')

# get_core_ids bash function definition

core_ids=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -d "-" -f 1 |  cut -d "," -f 1 | sort -u | tr '\n' ' ')
core_ids="$${core_ids[@]/0}"
IFS=', ' read -r -a core_ids <<< "$core_ids"
core_idx_begin=0
get_core_ids() {
	core_idx_end=$(($core_idx_begin + $1))
	res=$${core_ids["$core_idx_begin"]}
	for (( i=$(($core_idx_begin + 1)); i<$core_idx_end; i++ ))
	do
		res=$res,$${core_ids[i]}
	done
	core_idx_begin=$core_idx_end
	eval "$2=$res"
}


	# getNetStrForDpdk bash function definitiion

function getNetStrForDpdk() {
	i=$1
	j=$2
	gateways=$3
	subnets=$4

	if [ -n "$gateways" ]; then #azure and gcp
		gateways=($gateways)
	fi

	if [ -n "$subnets" ]; then #azure only
		subnets=($subnets)
	fi

	net=" "
	for ((i; i<$j; i++)); do
		if [ -n "$subnets" ]; then
			subnet=$${subnets[$i]}
			subnet_inet=$(curl -s -H Metadata:true –noproxy “*” http://169.254.169.254/metadata/instance/network\?api-version\=2021-02-01 | jq --arg subnet "$subnet" '.interface[] | select(.ipv4.subnet[0].address==$subnet)' | jq -r .ipv4.ipAddress[0].privateIpAddress)
			eth=$(ifconfig | grep -B 1 $subnet_inet |  head -n 1 | cut -d ':' -f1)
		else
			eth=eth$i
			subnet_inet=$(ifconfig $eth | grep 'inet ' | awk '{print $2}')
		fi
		if [ -z $subnet_inet ];then
			net=""
			break
		fi
		enp=$(ls -l /sys/class/net/$eth/ | grep lower | awk -F"_" '{print $2}' | awk '{print $1}') #for azure
		if [ -z $enp ];then
			enp=$(ethtool -i $eth | grep bus-info | awk '{print $2}') #pci for gcp
		fi
		bits=$(ip -o -f inet addr show $eth | awk '{print $4}')
		IFS='/' read -ra netmask <<< "$bits"

		if [ -n "$gateways" ]; then
			gateway=$${gateways[$i]}
			net="$net --net $enp/$subnet_inet/$${netmask[1]}/$gateway"
		else
			net="$net --net $eth" #aws
		fi
	done
}


# install script

TOKEN=${get_weka_io_token}
INSTALL_URL=https://$TOKEN@get.weka.io/dist/v1/install/${weka_version}/${weka_version}

# https://gist.github.com/fungusakafungus/1026804
function retry {
  local retry_max=$1
  local retry_sleep=$2
  shift 2
  local count=$retry_max
  while [ $count -gt 0 ]; do
      "$@" && break
      count=$(($count - 1))
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "Retry failed [$retry_max]: $@"
      return 1
  }
  return 0
}

while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   sleep 2
done

retry 300 2 curl --fail --max-time 10 $INSTALL_URL | sh

weka local stop
weka local rm default --force

# weka containers setup
get_core_ids $NUM_DRIVE_CONTAINERS drive_core_ids
get_core_ids $NUM_COMPUTE_CONTAINERS compute_core_ids
get_core_ids $NUM_FRONTEND_CONTAINERS frontend_core_ids

if [[ $INSTALL_DPDK == true ]]; then
  getNetStrForDpdk 1 $(($NUM_DRIVE_CONTAINERS+1)) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name drives0 --base-port 14000 --cores $NUM_DRIVE_CONTAINERS --no-frontends --drives-dedicated-cores $NUM_DRIVE_CONTAINERS --failure-domain $FAILURE_DOMAIN --core-ids $drive_core_ids $net --dedicate
  getNetStrForDpdk $((1+$NUM_DRIVE_CONTAINERS)) $((1+$NUM_DRIVE_CONTAINERS+$NUM_COMPUTE_CONTAINERS )) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name compute0 --base-port 15000 --cores $NUM_COMPUTE_CONTAINERS --no-frontends --compute-dedicated-cores $NUM_COMPUTE_CONTAINERS  --memory $COMPUTE_MEMORY --failure-domain $FAILURE_DOMAIN --core-ids $compute_core_ids $net --dedicate
  getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$GATEWAYS" "$SUBNETS"
  sudo weka local setup container --name frontend0 --base-port 16000 --cores $NUM_FRONTEND_CONTAINERS --frontend-dedicated-cores $NUM_FRONTEND_CONTAINERS --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids $net --dedicate
else
  sudo weka local setup container --name drives0 --base-port 14000 --cores $NUM_DRIVE_CONTAINERS --no-frontends --drives-dedicated-cores $NUM_DRIVE_CONTAINERS --failure-domain $FAILURE_DOMAIN --core-ids $drive_core_ids  --dedicate
  sudo weka local setup container --name compute0 --base-port 15000 --cores $NUM_COMPUTE_CONTAINERS --no-frontends --compute-dedicated-cores $NUM_COMPUTE_CONTAINERS  --memory $COMPUTE_MEMORY --failure-domain $FAILURE_DOMAIN --core-ids $compute_core_ids  --dedicate
  sudo weka local setup container --name frontend0 --base-port 16000 --cores $NUM_FRONTEND_CONTAINERS --frontend-dedicated-cores $NUM_FRONTEND_CONTAINERS --allow-protocols true --failure-domain $FAILURE_DOMAIN --core-ids $frontend_core_ids  --dedicate
fi


# should not call 'clusterize' untill all 3 containers are up
ready_containers=0
while [ $ready_containers -ne 3 ];
do
  sleep 10
  ready_containers=$( weka local ps | grep -i 'running' | wc -l )
  echo "Running containers: $ready_containers"
done

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
INSTALL_DPDK=${install_cluster_dpdk}

CONTAINER_NAMES=(drives0 compute0 frontend0)
PORTS=(14000 15000 16000)

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

DRIVE_NUMS=( $(weka cluster container | grep drives | awk '{print $1;}') )

for drive_num in "$${DRIVE_NUMS[@]}"; do
	for (( d=0; d<$NVMES_NUM; d++ )); do
		if [ lsblk "/dev/nvme$d"n1 >/dev/null 2>&1 ];then
			weka cluster drive add $drive_num "/dev/nvme$d"n1 # azure
		else
			weka cluster drive add $drive_num "/dev/nvme0n$((d+1))" #gcp
		fi
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

weka cluster process
weka cluster drive
weka cluster container

full_capacity=$(weka status -J | jq .capacity.unprovisioned_bytes)
weka fs group create default
weka fs create default default "$full_capacity"B

if [[ $INSTALL_DPDK == true ]]; then
	weka alerts mute NodeRDMANotActive 365d
else
	weka alerts mute JumboConnectivity 365d
	weka alerts mute UdpModePerformanceWarning 365d
fi

echo "completed successfully" > /tmp/weka_clusterization_completion_validation
