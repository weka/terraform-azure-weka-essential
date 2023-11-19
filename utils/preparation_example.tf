data "azurerm_client_config" "current" {}

provider "azurerm" {
  subscription_id = "PUT YOUR SUBSCRIPTION ID HERE"
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

locals {
  prefix                    = "essential"
  cluster_name              = "test"
  rg_name                   = "example"
  vnet_rg_name              = "example"
  address_space             = "10.0.0.0/16"
  alphanumeric_cluster_name = lower(replace(local.cluster_name, "/\\W|_|\\s/", ""))
  alphanumeric_prefix_name  = lower(replace(local.prefix, "/\\W|_|\\s/", ""))
  obs_name                  = "${local.alphanumeric_prefix_name}${local.alphanumeric_cluster_name}obs"
  obs_container_name        = "${local.alphanumeric_prefix_name}-${local.alphanumeric_cluster_name}-obs"
  blob_obs_access_key_file  = "/tmp/${local.obs_name}"
}

module "network" {
  source        = "../modules/network"
  prefix        = local.prefix
  rg_name       = local.vnet_rg_name
  address_space = local.address_space
  subnet_prefix = "10.0.0.0/24"
}

module "dns" {
  source     = "../modules/dns"
  prefix     = local.prefix
  rg_name    = local.vnet_rg_name
  vnet_name  = module.network.vnet_name
  depends_on = [module.network]
}

data "azurerm_subnet" "subnet" {
  resource_group_name  = local.vnet_rg_name
  virtual_network_name = module.network.vnet_name
  name                 = module.network.subnet_name
  depends_on           = [module.network]
}

module "obs" {
  source              = "../modules/obs"
  rg_name             = local.rg_name
  subnet_id           = data.azurerm_subnet.subnet.id
  private_dns_zone_id = module.dns.private_dns_zone_id
  obs_name            = local.obs_name
  obs_container_name  = local.obs_container_name
  depends_on          = [module.dns]
}

output "obs_name" {
  value = local.obs_name
}

output "obs_container_name" {
  value = local.obs_container_name
}

data "azurerm_storage_account" "obs" {
  name                = local.obs_name
  resource_group_name = local.rg_name
  depends_on          = [module.obs]
}

resource "null_resource" "write_obs_blob_key" {
  provisioner "local-exec" {
    command = "echo ${data.azurerm_storage_account.obs.primary_access_key} > ${local.blob_obs_access_key_file}"
  }
}

output "blob_obs_access_key_location" {
  value = local.blob_obs_access_key_file
}