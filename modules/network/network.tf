data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

resource "azurerm_virtual_network" "vnet" {
  resource_group_name = var.rg_name
  location            = data.azurerm_resource_group.rg.location
  name                = "${var.prefix}-vnet"
  address_space       = [var.address_space]
  tags                = merge(var.tags_map)
  depends_on          = [data.azurerm_resource_group.rg]
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet" "subnet" {
  resource_group_name  = var.rg_name
  name                 = "${var.prefix}-subnet"
  address_prefixes     = [var.subnet_prefix]
  virtual_network_name = azurerm_virtual_network.vnet.name
  lifecycle {
    ignore_changes = [service_endpoint_policy_ids, service_endpoints]
  }
  depends_on = [data.azurerm_resource_group.rg, azurerm_virtual_network.vnet]
}

# ====================== NAT ============================= #
resource "azurerm_public_ip_prefix" "nat_ip" {
  count               = var.create_nat_gateway ? 1 : 0
  name                = "${var.prefix}-nat-ip"
  resource_group_name = var.rg_name
  location            = data.azurerm_resource_group.rg.location
  ip_version          = "IPv4"
  prefix_length       = 29
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat_gateway" {
  count                   = var.create_nat_gateway ? 1 : 0
  name                    = "${var.prefix}-nat-gateway"
  resource_group_name     = var.rg_name
  location                = data.azurerm_resource_group.rg.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "nat_ip_association" {
  count               = var.create_nat_gateway ? 1 : 0
  nat_gateway_id      = azurerm_nat_gateway.nat_gateway[0].id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_ip[0].id
  depends_on          = [azurerm_nat_gateway.nat_gateway, azurerm_public_ip_prefix.nat_ip]
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat_gateway_association" {
  count          = var.create_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
  depends_on     = [azurerm_subnet.subnet, azurerm_nat_gateway.nat_gateway]
}

# ====================== sg ssh ========================== #
resource "azurerm_network_security_rule" "sg_public_ssh" {
  count                       = length(var.allow_ssh_cidrs)
  name                        = "${var.prefix}-ssh-sg-${count.index}"
  resource_group_name         = data.azurerm_resource_group.rg.name
  priority                    = 1000 + (count.index + 1)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = element(var.allow_ssh_cidrs, count.index)
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.sg.name
}

# ====================== sg weka ========================== #
resource "azurerm_network_security_rule" "sg_weka" {
  count                       = length(var.allow_weka_api_cidrs)
  name                        = "${var.prefix}-weka-sg-${count.index}"
  resource_group_name         = data.azurerm_resource_group.rg.name
  priority                    = 2000 + (count.index + 1)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "14000"
  source_address_prefix       = element(var.allow_weka_api_cidrs, count.index)
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.sg.name
}

resource "azurerm_network_security_group" "sg" {
  name                = "${var.prefix}-sg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = merge(var.tags_map)

  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [data.azurerm_resource_group.rg]
}

resource "azurerm_subnet_network_security_group_association" "sg-association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.sg.id
  depends_on                = [azurerm_network_security_group.sg]
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnet_name" {
  value = azurerm_subnet.subnet.name
}
