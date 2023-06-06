data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnets" {
  count                = length(var.subnets_name)
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  name                 = var.subnets_name[count.index]
}

resource "azurerm_public_ip" "public_ip" {
  count               = var.assign_public_ip ? var.clients_number : 0
  name                = "${var.clients_name}-public-ip-${count.index}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "primary_client_nic_public" {
  count                         = var.assign_public_ip ? var.clients_number : 0
  name                          = "${var.clients_name}-primary-nic-${count.index}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = var.mount_clients_dpdk

  ip_configuration {
    primary                       = true
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnets[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

resource "azurerm_network_interface" "primary_client_nic_private" {
  count                         = var.assign_public_ip ? 0 : var.clients_number
  name                          = "${var.clients_name}-primary-nic-${count.index}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = var.mount_clients_dpdk

  ip_configuration {
    primary                       = true
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnets[0].id
    private_ip_address_allocation = "Dynamic"
  }
}


locals {
  secondary_nics_num = (var.nics - 1) * var.clients_number
  subnet_assigning_sequence = [
    for i in range(local.secondary_nics_num) : data.azurerm_subnet.subnets[i % (var.nics - 1) + 1].id
  ]
}

resource "azurerm_network_interface" "client_nic" {
  count                         = local.secondary_nics_num
  name                          = "${var.clients_name}-nic-${count.index + var.clients_number}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = var.mount_clients_dpdk

  ip_configuration {
    primary                       = true
    name                          = "ipconfig-${count.index + var.clients_number}"
    subnet_id                     = local.subnet_assigning_sequence[count.index]
    private_ip_address_allocation = "Dynamic"
  }

  lifecycle {
    precondition {
      condition     = length(var.subnets_name) >= var.nics
      error_message = "Each NIC's ipconfig should be on its own subnet."
    }
  }
}

locals {
  preparation_script = templatefile(var.preparation_template_file, {
    apt_repo_url     = var.apt_repo_url
    install_ofed     = var.custom_image_id == null ? var.install_ofed : false
    ofed_version     = var.ofed_version
    install_ofed_url = var.install_ofed_url
    nics_num         = var.nics
    install_dpdk     = var.mount_clients_dpdk
    subnet_range     = data.azurerm_subnet.subnets[0].address_prefix
    ofed_type        = var.linux_vm_image.ofed
  })

  install_weka_script = templatefile(var.install_weka_template_file,
    {
      get_weka_io_token = var.get_weka_io_token
      weka_version      = var.weka_version
      install_weka_url  = var.install_weka_url
  })

  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    all_subnets = join(" ", [
      for item in data.azurerm_subnet.subnets.*.address_prefix : split("/", item)[0]
    ])
    all_gateways = join(" ", [
      for item in data.azurerm_subnet.subnets.*.address_prefix : cidrhost(item, 1)
    ])
    nics_num           = var.nics
    backend_ip         = var.backend_ip
    mount_clients_dpdk = var.mount_clients_dpdk
  })


  primary_nic_ids = var.assign_public_ip ? azurerm_network_interface.primary_client_nic_public.*.id : azurerm_network_interface.primary_client_nic_private.*.id
  custom_data_parts = [
    local.preparation_script, local.install_weka_script,
    local.mount_wekafs_script
  ]
  vms_custom_data = base64encode(join("\n", local.custom_data_parts))
}

resource "azurerm_linux_virtual_machine" "default_image_vms" {
  count                           = var.custom_image_id == null ? var.clients_number : 0
  name                            = "${var.clients_name}-vm-${count.index}"
  computer_name                   = "${var.clients_name}-${count.index}"
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = var.rg_name
  size                            = var.instance_type
  admin_username                  = var.vm_username
  custom_data                     = local.vms_custom_data
  disable_password_authentication = true
  proximity_placement_group_id    = var.ppg_id
  tags                            = merge({ "weka_cluster" : var.clients_name })

  network_interface_ids = concat(
    # The first Network Interface ID in this list is the Primary Network Interface on the Virtual Machine.
    [local.primary_nic_ids[count.index]],
    slice(azurerm_network_interface.client_nic.*.id, (var.nics - 1) * count.index, (var.nics - 1) * (count.index + 1))
  )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }

  admin_ssh_key {
    username   = var.vm_username
    public_key = var.ssh_public_key
  }

  lifecycle {
    ignore_changes = [custom_data]
  }
}

resource "azurerm_linux_virtual_machine" "custom_image_vms" {
  count                           = var.custom_image_id != null ? var.clients_number : 0
  name                            = "${var.clients_name}-vm-${count.index}"
  computer_name                   = "${var.clients_name}-${count.index}"
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = var.rg_name
  size                            = var.instance_type
  admin_username                  = var.vm_username
  custom_data                     = local.vms_custom_data
  disable_password_authentication = true
  proximity_placement_group_id    = var.ppg_id
  tags                            = merge({ "weka_cluster" : var.clients_name })
  source_image_id                 = var.custom_image_id

  network_interface_ids = concat(
    # The first Network Interface ID in this list is the Primary Network Interface on the Virtual Machine.
    [local.primary_nic_ids[count.index]],
     slice(azurerm_network_interface.client_nic.*.id, (var.nics - 1) * count.index, (var.nics - 1) * (count.index + 1))
  )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.vm_username
    public_key = var.ssh_public_key
  }

  lifecycle {
    ignore_changes = [custom_data]
  }
}
