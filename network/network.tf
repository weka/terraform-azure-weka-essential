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
  count                = length(var.subnet_prefixes)
  resource_group_name  = var.rg_name
  name                 = "${var.prefix}-subnet-${count.index}"
  address_prefixes     = [var.subnet_prefixes[count.index]]
  virtual_network_name = azurerm_virtual_network.vnet.name
  lifecycle {
    ignore_changes = [service_endpoint_policy_ids, service_endpoints]
  }
  depends_on = [data.azurerm_resource_group.rg, azurerm_virtual_network.vnet]
}


# ====================== sg ssh ========================== #
resource "azurerm_network_security_rule" "sg_public_ssh" {
  count                       = var.private_network ? 0 : 1
  name                        = "${var.prefix}-ssh-sg-${count.index}"
  resource_group_name         = data.azurerm_resource_group.rg.name
  priority                    = "100${count.index}"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = ["0.0.0.0/0"]
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.sg.name
}

# ====================== sg weka ========================== #
resource "azurerm_network_security_rule" "sg_weka" {
  name                        = "${var.prefix}-weka-sg"
  resource_group_name         = data.azurerm_resource_group.rg.name
  priority                    = "1002"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "14000"
  source_address_prefix       = "*"
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
  count                     = length(var.subnet_prefixes)
  subnet_id                 = azurerm_subnet.subnet[count.index].id
  network_security_group_id = azurerm_network_security_group.sg.id
  depends_on                = [azurerm_network_security_group.sg]
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnets_names" {
  value = azurerm_subnet.subnet.*.name
}
