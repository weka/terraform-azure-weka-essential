locals {
  clusterize_script = templatefile("${path.module}/clusterize.sh", {
    vm_names            = join(" ", local.vms_computer_names)
    private_ips         = join(" ", slice(local.first_nic_private_ips, 0, var.cluster_size - 1))
    cluster_name        = var.cluster_name
    cluster_size        = var.cluster_size
    nvmes_num           = var.container_number_map[var.instance_type].nvme
    stripe_width        = var.stripe_width
    protection_level    = var.protection_level
    hotspare            = var.hotspare
    install_dpdk        = var.install_cluster_dpdk
    set_obs             = var.set_obs
    tiering_ssd_percent = var.tiering_ssd_percent
    obs_name            = var.obs_name
    obs_container_name  = var.obs_container_name
    blob_obs_access_key = var.blob_obs_access_key
  })
}

resource "azurerm_linux_virtual_machine" "clusterizing" {
  name                            = "${var.prefix}-${var.cluster_name}-clusterizing"
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = var.rg_name
  size                            = var.instance_type
  admin_username                  = var.vm_username
  computer_name                   = "${var.prefix}-${var.cluster_name}-backend-${var.cluster_size - 1}"
  disable_password_authentication = true
  custom_data                     = base64encode(join("\n", [
    local.preparation_script, local.attach_disk_script,
    local.install_weka_script, local.deploy_script, local.clusterize_script
  ]))
  proximity_placement_group_id    = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  network_interface_ids           = concat([local.first_nic_ids[var.cluster_size - 1]], slice(azurerm_network_interface.private_nics.*.id, ( local.nics_numbers - 1 )* (var.cluster_size - 1), (local.nics_numbers - 1) * var.cluster_size))
  tags                            = merge(var.tags_map,{"weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id })
  source_image_reference {
    offer     = var.linux_vm_image[var.os_type].offer
    publisher = var.linux_vm_image[var.os_type].publisher
    sku       = var.linux_vm_image[var.os_type].sku
    version   = var.linux_vm_image[var.os_type].version
  }
  dynamic "plan" {
    for_each = var.os_type != "ubuntu" ? [1] : []
    content {
      name      = var.linux_vm_image[var.os_type].sku
      product   = var.linux_vm_image[var.os_type].offer
      publisher = var.linux_vm_image[var.os_type].publisher
    }
  }
  os_disk {
    caching              = "ReadWrite"
    name                 = "clusterizing-os-disk-${var.prefix}-${var.cluster_name}-${var.cluster_size - 1}"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    public_key = local.public_ssh_key
    username     = var.vm_username
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [module.network, azurerm_proximity_placement_group.ppg, azurerm_linux_virtual_machine.vms]
}



resource "azurerm_managed_disk" "clusterize_disks" {
  name                 = "weka-disk-${var.prefix}-${var.cluster_name}-clusterize"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = var.rg_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = local.disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "clusterize_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.clusterize_disks.id
  virtual_machine_id = azurerm_linux_virtual_machine.clusterizing.id
  lun                = 0
  caching            = "ReadWrite"
  depends_on         = [azurerm_linux_virtual_machine.clusterizing]
}