echo "$(date -u): before weka agent installation"

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

IFS=" " read -ra ips <<< "${backend_ips}"
backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
# install weka using random backend ip from ips list
function retry_weka_install {
  retry_max=60
  retry_sleep=30
  count=$retry_max

  while [ $count -gt 0 ]; do
      curl --fail -o install_script.sh $backend_ip:14000/dist/v1/install && break
      count=$(($count - 1))
      backend_ip="$${ips[RANDOM % $${#ips[@]}]}"
      echo "Retrying weka install from $backend_ip in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "weka install failed after $retry_max attempts"
      echo "$(date -u): weka install failed"
      return 1
  }
  chmod +x install_script.sh && ./install_script.sh
  return 0
}

retry_weka_install

echo "$(date -u): weka agent installation complete"

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need
mkdir -p $MOUNT_POINT

weka local stop && weka local rm -f --all

gateways="${all_gateways}"
subnets="${all_subnets}"
FRONTEND_CONTAINER_CORES_NUM="${frontend_container_cores_num}"
NICS_NUM=$((FRONTEND_CONTAINER_CORES_NUM+1))
net_option_name="-o net="
eth0=$(ifconfig | grep eth0 -C2 | grep 'inet ' | awk '{print $2}')

mount_command="mount -t wekafs -o net=udp $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
if [[ ${mount_clients_dpdk} == true ]]; then
  getNetStrForDpdk 1 $NICS_NUM $gateways $subnets "$net_option_name"
  mount_command="mount -t wekafs $net -o num_cores=$FRONTEND_CONTAINER_CORES_NUM -o mgmt_ip=$eth0 $backend_ip/$FILESYSTEM_NAME $MOUNT_POINT"
fi

retry 60 45 $mount_command

rm -rf $INSTALLATION_PATH
echo "$(date -u): wekafs mount complete"
