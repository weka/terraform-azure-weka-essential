INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

# getNetStrForDpdk bash function definitiion
function getNetStrForDpdk() {
  i=$1
  j=$2
  gateways=$3
  subnets=$4
  net_option_name=$5

  if [ "$#" -lt 5 ]; then
      echo "'net_option_name' argument is not provided. Using default value: --net"
      net_option_name="--net "
  fi

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
      eth=$(ifconfig | grep -B 1 "$subnet_inet" |  head -n 1 | cut -d ':' -f1)
    else
      eth=eth$i
      subnet_inet=$(ifconfig $eth | grep 'inet ' | awk '{print $2}')
    fi
    if [ -z "$subnet_inet" ];then
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
      net="$net $net_option_name$enp/$subnet_inet/$${netmask[1]}/$gateway"
    else
      net="$net $net_option_name$eth" #aws
    fi
	done
}

# install script
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

TOKEN=${get_weka_io_token}
INSTALL_URL=https://$TOKEN@get.weka.io/dist/v1/install/${weka_version}/${weka_version}

if [[ "${install_weka_url}" != "" ]]; then
    wget -P $INSTALLATION_PATH ${install_weka_url}
    IFS='/' read -ra tar_str <<< "${install_weka_url}"
    pkg_name=$(cut -d'/' -f"$${#tar_str[@]}" <<< ${install_weka_url})
    cd $INSTALLATION_PATH
    tar -xvf $pkg_name
    tar_folder=$(echo $pkg_name | sed 's/.tar//')
    cd $INSTALLATION_PATH/$tar_folder
    ./install.sh
  else
    retry 300 2 curl --fail --max-time 10 $INSTALL_URL | sh
fi
