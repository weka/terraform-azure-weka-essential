data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnet" {
  resource_group_name  = var.vnet_rg_name
  virtual_network_name = var.vnet_name
  name                 = var.subnet_name
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
    subnet_id                     = data.azurerm_subnet.subnet.id
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
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


locals {
  secondary_nics_num = (var.nics - 1) * var.clients_number
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
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

locals {
  preparation_script = templatefile(var.preparation_template_file, {
    apt_repo_url     = var.apt_repo_url
    nics_num         = var.nics
    install_dpdk     = var.mount_clients_dpdk
    subnet_range     = data.azurerm_subnet.subnet.address_prefix
  })

  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    all_subnets = split("/", data.azurerm_subnet.subnet.address_prefix)[0]
    all_gateways = cidrhost(data.azurerm_subnet.subnet.address_prefix, 1)
    nics_num           = var.nics
    backend_ips        = join(" ", var.backend_ips)
    mount_clients_dpdk = var.mount_clients_dpdk
  })


  primary_nic_ids = var.assign_public_ip ? azurerm_network_interface.primary_client_nic_public.*.id : azurerm_network_interface.primary_client_nic_private.*.id
  custom_data_parts = [local.preparation_script, local.mount_wekafs_script]
  vms_custom_data = base64encode(join("\n", local.custom_data_parts))
}

resource "azurerm_linux_virtual_machine" "vms" {
  count                           = var.clients_number
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
  source_image_id                 = var.source_image_id

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
