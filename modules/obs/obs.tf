data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

resource "azurerm_private_endpoint" "endpoint" {
  name                = "${var.obs_name}-endpoint"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.obs_name}-private-connection"
    private_connection_resource_id = azurerm_storage_account.obs.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_storage_account" "obs" {
  name                          = var.obs_name
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = var.rg_name
  account_kind                  = "StorageV2"
  account_tier                  = "Standard"
  account_replication_type      = "ZRS"
  public_network_access_enabled = true
  enable_https_traffic_only     = false
}

resource "azurerm_storage_container" "obs-container" {
  name                  = var.obs_container_name
  storage_account_name  = azurerm_storage_account.obs.name
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.obs]
}