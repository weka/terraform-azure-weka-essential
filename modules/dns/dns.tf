data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone" "dns" {
  name                = "${var.prefix}.private.net"
  resource_group_name = var.rg_name
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_dns_link" {
  name                  = "${var.prefix}-private-network-link"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  registration_enabled  = true
  lifecycle {
    ignore_changes = [tags]
  }
}
