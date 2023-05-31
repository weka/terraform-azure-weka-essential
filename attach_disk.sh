wekaiosw_device=/dev/"$(lsblk | grep ${disk_size}G | awk '{print $1}')"

status=0
mkfs.ext4 -L wekaiosw $wekaiosw_device
mkdir -p /opt/weka 2>&1
mount $wekaiosw_device /opt/weka

echo "LABEL=wekaiosw /opt/weka ext4 defaults 0 2" >>/etc/fstab
