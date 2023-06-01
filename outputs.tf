/*
TF documentation:
Dynamic Public IP Addresses aren't allocated until they're attached to a device (e.g. a Virtual Machine/Load Balancer).
Instead you can obtain the IP Address once the Public IP has been assigned via the azurerm_public_ip Data Source.
*/
data "azurerm_public_ip" "public_ips" {
  count               = var.assign_public_ip ? var.cluster_size : 0
  name                = azurerm_public_ip.publicIp[count.index].name
  resource_group_name = var.rg_name
  depends_on = [azurerm_virtual_machine.vms, azurerm_virtual_machine.clusterizing]
}

output "backends_ips" {
  value       = var.assign_public_ip ? data.azurerm_public_ip.public_ips.*.ip_address : local.first_nic_private_ips
  description = "Weka backends ips. If 'assign_public_ip' is set to true, it will output public ips, otherwise private ips"
}

output "client_ips" {
  value       = length(module.clients) > 0 ? module.clients.0.client-ips : null
  description = "Weka clients ips. If 'assign_public_ip' is set to true, it will output public ips, otherwise private ips"
}
