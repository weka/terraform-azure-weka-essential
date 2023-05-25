data "template_file" "clusterize" {
  template = file("${path.module}/clusterize.sh")
  vars     = {
    user                 = var.vm_username
    ofed_version         = var.ofed_version
    install_ofed         = var.install_ofed
    install_ofed_url     = var.install_ofed_url
    install_cluster_dpdk = var.install_cluster_dpdk
    subnet_range         = local.subnet_range
    nics_num             = local.nics_numbers
    disk_size            = local.disk_size
    all_subnets          = join(" ", [
    for item in data.azurerm_subnet.subnets.*.address_prefix :
    split("/", item)[0]
    ])
    subnet_prefixes   = join(" ", [for item in data.azurerm_subnet.subnets.*.address_prefix : item])
    memory            = var.container_number_map[var.instance_type].memory
    compute_num       = var.container_number_map[var.instance_type].compute
    frontend_num      = var.container_number_map[var.instance_type].frontend
    drive_num         = var.container_number_map[var.instance_type].drive
    nics_num          = var.container_number_map[var.instance_type].nics
    get_weka_io_token = var.get_weka_io_token
    weka_version      = var.weka_version
    private_ips       = join(" ", slice(local.first_nic_private_ips, 0, var.cluster_size - 1))
    vm_names          = join(" ", local.vms_computer_names)
    cluster_name      = var.cluster_name
    cluster_size      = var.cluster_size
    nvmes_num         = var.container_number_map[var.instance_type].nvme
    stripe_width      = var.stripe_width
    protection_level  = var.protection_level
    hotspare          = var.hotspare
  }
}

data "template_cloudinit_config" "cloud_init_clusterize" {
  gzip = false
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.clusterize.rendered
  }
}

resource "azurerm_virtual_machine" "clusterizing" {
  name                = "${var.prefix}-${var.cluster_name}-clusterizing"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  vm_size             = var.instance_type
  os_profile {
    admin_username = var.vm_username
    computer_name  = "${var.prefix}-${var.cluster_name}-backend-${var.cluster_size - 1}"
    custom_data    = base64encode(data.template_file.clusterize.rendered)
  }
  proximity_placement_group_id = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  tags                         = merge(var.tags_map, {
    "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id
  })
  #  source_image_id = "/subscriptions/d2f248b9-d054-477f-b7e8-413921532c2a/resourceGroups/weka-tf/providers/Microsoft.Compute/images/weka-ubuntu20-ofed-5.8-1.1.2.1"
  storage_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }
  storage_os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
    name          = "os_disk-${var.prefix}-${var.cluster_name}-${var.cluster_size - 1}"
  }
  storage_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = local.disk_size
    name          = "traces-${var.prefix}-${var.cluster_name}-${var.cluster_size - 1}"
  }

  os_profile_linux_config {
    ssh_keys {
      key_data = local.public_ssh_key
      path     = "/home/weka/.ssh/authorized_keys"
    }
    disable_password_authentication = true
  }

  identity {
    type = "SystemAssigned"
  }

  primary_network_interface_id = local.first_nic_ids[var.cluster_size - 1]
  network_interface_ids        = concat(
    [local.first_nic_ids[var.cluster_size - 1]],
    slice(azurerm_network_interface.private_nics.*.id, ( local.nics_numbers - 1 )* (var.cluster_size - 1), (local.nics_numbers - 1) * var.cluster_size)
  )
  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [module.network, azurerm_proximity_placement_group.ppg]
}
