resource "azurerm_public_ip" "publicIp" {
  count                         = var.private_network ? 0 : var.cluster_size
  name                = "publicIp-${var.prefix}-${var.cluster_name}-${count.index}"
  resource_group_name = var.rg_name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "public_first_nic" {
  count                         = var.private_network ? 0 : var.cluster_size
  name                          = "${var.prefix}-${var.cluster_name}-backend-nic-${count.index}"
  enable_accelerated_networking = var.install_cluster_dpdk
  resource_group_name           = var.rg_name
  location                      = data.azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnets[0].id
    private_ip_address_allocation = "Dynamic"
    primary = true
    public_ip_address_id = azurerm_public_ip.publicIp[count.index].id
  }
}

resource "azurerm_network_interface" "private_first_nic" {
  count                         = var.private_network ? var.cluster_size : 0
  name                          = "${var.prefix}-${var.cluster_name}-backend-nic-${count.index}"
  enable_accelerated_networking = var.install_cluster_dpdk
  resource_group_name           = var.rg_name
  location                      = data.azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "ipconfig0"
    subnet_id                     = data.azurerm_subnet.subnets[0].id
    private_ip_address_allocation = "Dynamic"
    primary = true
  }
}

resource "azurerm_network_interface" "private_nics" {
  count                         = (local.nics_numbers - 1) * var.cluster_size
  name                          = "${var.prefix}-${var.cluster_name}-backend-nic-${count.index + var.cluster_size}"
  enable_accelerated_networking = var.install_cluster_dpdk
  resource_group_name           = var.rg_name
  location                      = data.azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "ipconfig${count.index + var.cluster_size}"
    subnet_id                     = data.azurerm_subnet.subnets[count.index % (local.nics_numbers - 1) + 1].id
    private_ip_address_allocation = "Dynamic"
  }
}
