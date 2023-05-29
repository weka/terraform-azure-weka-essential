FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need
mkdir -p $MOUNT_POINT

weka local stop
weka local rm default --force
weka local stop && weka local rm -f --all

gateways="${all_gateways}"
subnets="${all_subnets}"
NICS_NUM="${nics_num}"
eth0=$(ifconfig | grep eth0 -C2 | grep 'inet ' | awk '{print $2}')

mount_command="mount -t wekafs -o net=udp ${backend_ip}/$FILESYSTEM_NAME $MOUNT_POINT"
if [[ ${install_dpdk} == true ]]; then
  getNetStrForDpdk $(($NICS_NUM-1)) $(($NICS_NUM)) "$gateways" "$subnets" "-o net="
  mount_command="mount -t wekafs $net -o num_cores=1 -o mgmt_ip=$eth0 ${backend_ip}/$FILESYSTEM_NAME $MOUNT_POINT"
fi

cat <<'EOF' > retry_mount.sh
#!/bin/bash

mount_command=$1
retry_count=0
max_retries=5
retry_interval=30

while true; do
    eval "$mount_command" && break

    ((retry_count++))
    if [ $retry_count -eq $max_retries ]; then
        echo "Mount wekafs failed after $max_retries retries."
        exit 1
    fi

    echo "Mount wekafs failed. Retrying in $retry_interval seconds..."
    sleep $retry_interval
done

echo "Mounted wekafs successfully!"
EOF

chmod +x retry_mount.sh
./retry_mount.sh "$mount_command"

rm -rf $INSTALLATION_PATH
