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
    private_ips       = join(" ", data.azurerm_virtual_machine_scale_set.vms.instances.*.private_ip_address)
    vm_names          = join(" ", data.azurerm_virtual_machine_scale_set.vms.instances.*.computer_name)
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

resource "azurerm_linux_virtual_machine_scale_set" "clusterizing" {
  name                            = "${var.prefix}-${var.cluster_name}-clusterizing-vmss"
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = var.rg_name
  sku                             = var.instance_type
  upgrade_mode                    = "Manual"
  admin_username                  = var.vm_username
  instances                       = 1
  computer_name_prefix            = "${var.prefix}-${var.cluster_name}-clusterizing-backend"
  custom_data                     = base64encode(data.template_file.clusterize.rendered)
  disable_password_authentication = true
  overprovision                   = false
  proximity_placement_group_id    = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  tags                            = merge(var.tags_map, {
    "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id
  })
  #  source_image_id = "/subscriptions/d2f248b9-d054-477f-b7e8-413921532c2a/resourceGroups/weka-tf/providers/Microsoft.Compute/images/weka-ubuntu20-ofed-5.8-1.1.2.1"
  source_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  data_disk {
    lun                  = 0
    caching              = "ReadWrite"
    create_option        = "Empty"
    disk_size_gb         = local.disk_size
    storage_account_type = "StandardSSD_LRS"
  }

  admin_ssh_key {
    username   = var.vm_username
    public_key = local.public_ssh_key
  }

  identity {
    type = "SystemAssigned"
  }

  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      name                          = "${var.prefix}-${var.cluster_name}-clusterizing-backend-nic-0"
      primary                       = true
      enable_accelerated_networking = var.install_cluster_dpdk
      ip_configuration {
        primary   = true
        name      = "ipconfig0"
        subnet_id = data.azurerm_subnet.subnets[0].id
        public_ip_address {
          name              = "${var.prefix}-${var.cluster_name}-clusterizing-public-ip"
          domain_name_label = "${var.prefix}-${var.cluster_name}-clusterizing-backend"
        }
      }
    }
  }
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, 1)
    content {
      name                          = "${var.prefix}-${var.cluster_name}-clusterizing-backend-nic-0"
      primary                       = true
      enable_accelerated_networking = var.install_cluster_dpdk
      ip_configuration {
        primary   = true
        name      = "ipconfig0"
        subnet_id = data.azurerm_subnet.subnets[0].id
      }
    }
  }
  dynamic "network_interface" {
    for_each = range(1, local.nics_numbers)
    content {
      name                          = "${var.prefix}-${var.cluster_name}-clusterizing-backend-nic-${network_interface.value}"
      primary                       = false
      enable_accelerated_networking = var.install_cluster_dpdk
      ip_configuration {
        primary   = false
        name      = "ipconfig${network_interface.value}"
        subnet_id = data.azurerm_subnet.subnets[network_interface.value].id
      }
    }
  }
  lifecycle {
    ignore_changes = [instances, custom_data, tags]
  }
  depends_on = [module.network]
}

data "azurerm_virtual_machine_scale_set" "clusterizing" {
  name                = azurerm_linux_virtual_machine_scale_set.clusterizing.name
  resource_group_name = var.rg_name
}

output "clusterizing_private_ip" {
  value = data.azurerm_virtual_machine_scale_set.clusterizing.instances.*.private_ip_address
}

output "clusterizing_public_ip" {
  value = data.azurerm_virtual_machine_scale_set.clusterizing.instances.*.public_ip_address
}
