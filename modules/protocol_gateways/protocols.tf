data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnet" {
  resource_group_name  = var.vnet_rg_name
  virtual_network_name = var.vnet_name
  name                 = var.subnet_name
}

resource "azurerm_public_ip" "public_ip" {
  count               = var.assign_public_ip ? var.gateways_number : 0
  name                = "${var.gateways_name}-public-ip-${count.index}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "primary_gateway_nic_public" {
  count                         = var.assign_public_ip ? var.gateways_number : 0
  name                          = "${var.gateways_name}-primary-nic-${count.index}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    primary                       = true
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }

  // secondary ips (floating ip)
  dynamic "ip_configuration" {
    for_each = range(var.secondary_ips_per_nic)
    content {
      name                          = "ipconfig${ip_configuration.value + 1}"
      subnet_id                     = data.azurerm_subnet.subnet.id
      private_ip_address_allocation = "Dynamic"
    }
  }
}

resource "azurerm_network_interface" "primary_gateway_nic_private" {
  count                         = var.assign_public_ip ? 0 : var.gateways_number
  name                          = "${var.gateways_name}-primary-nic-${count.index}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    primary                       = true
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  // secondary ips (floating ip)
  dynamic "ip_configuration" {
    for_each = range(var.secondary_ips_per_nic)
    content {
      name                          = "ipconfig${ip_configuration.value + 1}"
      subnet_id                     = data.azurerm_subnet.subnet.id
      private_ip_address_allocation = "Dynamic"
    }
  }
}

locals {
  secondary_nics_num = (var.nics - 1) * var.gateways_number
}

resource "azurerm_network_interface" "secondary_gateway_nic" {
  count                         = local.secondary_nics_num
  name                          = "${var.gateways_name}-secondary-nic-${count.index + var.gateways_number}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    primary                       = true
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

locals {
  disk_size             = var.disk_size + var.traces_per_frontend * var.frontend_num
  first_nic_ids         = var.assign_public_ip ? azurerm_network_interface.primary_gateway_nic_public.*.id : azurerm_network_interface.primary_gateway_nic_private.*.id
  first_nic_private_ips = var.assign_public_ip ? azurerm_network_interface.primary_gateway_nic_public.*.private_ip_address : azurerm_network_interface.primary_gateway_nic_private.*.private_ip_address

  preparation_script = templatefile("${path.module}/../../preparation.sh", {
    apt_repo_url = var.apt_repo_url
    nics_num     = var.nics
    subnet_range = data.azurerm_subnet.subnet.address_prefix
  })

  attach_disk_script = templatefile("${path.module}/../../attach_disk.sh", {
    disk_size = local.disk_size
  })

  install_weka_script = templatefile("${path.module}/../../install_weka_template.sh", {
    install_weka_url  = var.install_weka_url
  })

  deploy_script = templatefile("${path.module}/deploy_protocol_gateways.sh", {
    frontend_num    = var.frontend_num
    subnet_prefixes = data.azurerm_subnet.subnet.address_prefix
    backend_ips     = join(",", var.backend_ips)
    nics_num        = var.nics
  })

  setup_nfs_protocol_script = templatefile("${path.module}/setup_nfs.sh", {
    gateways_name        = var.gateways_name
    interface_group_name = var.interface_group_name
    client_group_name    = var.client_group_name
  })

  setup_smb_protocol_script = templatefile("${path.module}/setup_smb.sh", {})

  setup_protocol_script = var.protocol == "NFS" ? local.setup_nfs_protocol_script : local.setup_smb_protocol_script

  custom_data_parts = [
    local.preparation_script, local.attach_disk_script,
    local.install_weka_script, local.deploy_script, local.setup_protocol_script
  ]
  custom_data = join("\n", local.custom_data_parts)
}

resource "azurerm_linux_virtual_machine" "vms" {
  count                           = var.gateways_number
  name                            = "${var.gateways_name}-vm-${count.index}"
  computer_name                   = "${var.gateways_name}-${count.index}"
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = var.rg_name
  size                            = var.instance_type
  admin_username                  = var.vm_username
  custom_data                     = base64encode(local.custom_data)
  proximity_placement_group_id    = var.ppg_id
  disable_password_authentication = true
  source_image_id                 = var.source_image_id
  tags                            = merge(var.tags_map, { "weka_protocol_gateways" : var.gateways_name, "user_id" : data.azurerm_client_config.current.object_id })

  network_interface_ids = concat(
    [local.first_nic_ids[count.index]],
    slice(azurerm_network_interface.secondary_gateway_nic.*.id, (var.nics - 1) * count.index, (var.nics - 1) * (count.index + 1))
  )

  os_disk {
    caching              = "ReadWrite"
    name                 = "os-disk-${var.gateways_name}-${count.index}"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = var.vm_username
    public_key = var.ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [tags]
    precondition {
      condition     = var.protocol == "NFS" ? var.gateways_number >= 1 : var.gateways_number >= 3
      error_message = "The amount of protocol gateways should be at least 1 for NFS and 3 for SMB."
    }
  }
}

resource "azurerm_managed_disk" "vm_disks" {
  count                = var.gateways_number
  name                 = "weka-disk-${var.gateways_name}-${count.index}"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = var.rg_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = local.disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm_disk_attachment" {
  count              = var.gateways_number
  managed_disk_id    = azurerm_managed_disk.vm_disks[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vms[count.index].id
  lun                = 0
  caching            = "ReadWrite"
  depends_on         = [azurerm_linux_virtual_machine.vms]
}
