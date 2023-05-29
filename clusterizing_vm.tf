data "template_file" "clusterize" {
  template = file("${path.module}/clusterize.sh")
  vars     = {
    vm_names             = join(" ", local.vms_computer_names)
    private_ips          = join(" ", slice(local.first_nic_private_ips, 0, var.cluster_size - 1))
    cluster_name         = var.cluster_name
    cluster_size         = var.cluster_size
    nvmes_num            = var.container_number_map[var.instance_type].nvme
    stripe_width         = var.stripe_width
    protection_level     = var.protection_level
    hotspare             = var.hotspare
    install_cluster_dpdk = var.install_cluster_dpdk
  }
  depends_on = [azurerm_virtual_machine.vms]
}

resource "azurerm_virtual_machine" "clusterizing" {
  name                = "${var.prefix}-${var.cluster_name}-clusterizing"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  vm_size             = var.instance_type
  os_profile {
    admin_username = var.vm_username
    computer_name  = "${var.prefix}-${var.cluster_name}-backend-${var.cluster_size - 1}"
    custom_data    = base64encode(format("%s\n%s", data.template_file.deploy.rendered, data.template_file.clusterize.rendered))
  }
  proximity_placement_group_id = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  tags                         = merge(var.tags_map, {
    "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id
  })
  storage_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }
  storage_os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
    name          = "os-disk-${var.prefix}-${var.cluster_name}-${var.cluster_size - 1}"
  }
  storage_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = local.disk_size
    name          = "weka-disk-${var.prefix}-${var.cluster_name}-${var.cluster_size - 1}" # will be used for /opt/weka
  }
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

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
  depends_on = [module.network, azurerm_proximity_placement_group.ppg, azurerm_virtual_machine.vms]
}
