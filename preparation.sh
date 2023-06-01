#!/bin/bash
set -ex

systemctl stop unattended-upgrades
systemctl disable unattended-upgrades
while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/{lock,lock-frontend} >/dev/null 2>&1; do
   sleep 2
done

apt update -y
apt install net-tools -y

# set apt private repo
if [[ "${apt_repo_url}" != "" ]]; then
  mv /etc/apt/sources.list /etc/apt/sources.list.bak
  echo "deb ${apt_repo_url} focal main restricted universe" > /etc/apt/sources.list
  echo "deb ${apt_repo_url} focal-updates main restricted" >> /etc/apt/sources.list
fi

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH

# install ofed
if [[ ${install_ofed} == true ]]; then
  OFED_NAME=ofed-${ofed_version}
  if [[ "${install_ofed_url}" ]]; then
    wget "${install_ofed_url}" -O $INSTALLATION_PATH/$OFED_NAME.tgz
  else
    wget https://content.mellanox.com/ofed/MLNX_OFED-${ofed_version}/MLNX_OFED_LINUX-${ofed_version}-${ofed_type}-x86_64.tgz -O $INSTALLATION_PATH/$OFED_NAME.tgz
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
if [[ ${install_dpdk} == true ]]; then
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

apt install -y jq

# remove installation path before installing weka
rm -rf $INSTALLATION_PATH
