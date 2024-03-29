/*
TF documentation:
Dynamic Public IP Addresses aren't allocated until they're attached to a device (e.g. a Virtual Machine/Load Balancer).
Instead you can obtain the IP Address once the Public IP has been assigned via the azurerm_public_ip Data Source.
*/
data "azurerm_public_ip" "public_ips" {
  count               = var.assign_public_ip ? var.cluster_size : 0
  name                = azurerm_public_ip.publicIp[count.index].name
  resource_group_name = var.rg_name
  depends_on          = [azurerm_linux_virtual_machine.vms, azurerm_linux_virtual_machine.clusterizing]
}

output "backend_ips" {
  value       = flatten(var.assign_public_ip ? data.azurerm_public_ip.public_ips.*.ip_address : local.first_nic_private_ips)
  description = "If 'assign_public_ip' is set to true, it will output backends public ips, otherwise private ips."
}

output "client_ips" {
  value       = length(module.clients) > 0 ? flatten(module.clients.0.client_ips) : null
  description = "If 'assign_public_ip' is set to true, it will output clients public ips, otherwise private ips."
}

output "nfs_protocol_gateway_ips" {
  value       = var.nfs_protocol_gateways_number > 0 ? module.nfs_protocol_gateways[0].protocol_gateways_ips : null
  description = "If 'private_network' is set to false, it will output nfs protocol gateway public ips, otherwise private ips."
}

output "smb_protocol_gateway_ips" {
  value       = var.smb_protocol_gateways_number > 0 ? module.smb_protocol_gateways[0].protocol_gateways_ips : null
  description = "If 'private_network' is set to false, it will output smb protocol gateway public ips, otherwise private ips."
}

output "vm_username" {
  value       = var.vm_username
  description = "Provided as part of output for automated use of terraform, ssh user to weka cluster vm"
}

output "private_ssh_key" {
  value       = var.ssh_public_key == null ? local.ssh_private_key_path : null
  description = "private_ssh_key:  If 'ssh_public_key' is set to null, it will output the private ssh key location."
}
