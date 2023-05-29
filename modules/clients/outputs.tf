output "client-ips" {
  value = (
    var.custom_image_id == null
    ? var.assign_public_ip ? azurerm_linux_virtual_machine.default_image_vms.*.public_ip_address : azurerm_linux_virtual_machine.default_image_vms.*.private_ip_address
    : var.assign_public_ip ? azurerm_linux_virtual_machine.custom_image_vms.*.public_ip_address : azurerm_linux_virtual_machine.custom_image_vms.*.private_ip_address
  )
}
