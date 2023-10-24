output "client_ips" {
  value = var.assign_public_ip ? azurerm_linux_virtual_machine.vms.*.public_ip_address : azurerm_linux_virtual_machine.vms.*.private_ip_address
}
