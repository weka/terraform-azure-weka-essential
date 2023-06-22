#provider "azurerm" {
#  subscription_id = var.subscription_id
#  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
#  features {
#  }
#}
#
#data "azuread_client_config" "current" {}
#
#data "azurerm_subscription" "primary" {}
#
#locals {
#  custom_role_definitions = {
#    "${var.prefix}_custom_role" = {
#      description = "Custom Role to allow create weka resources under resource group ${var.rg_name}"
#      scope       = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"
#
#      permissions = {
#        actions = [
#          "Microsoft.Network/virtualNetworks/read",
#          "Microsoft.Network/virtualNetworks/write",
#          "Microsoft.Network/virtualNetworks/delete",
#          "Microsoft.Network/virtualNetworks/subnets/read",
#          "Microsoft.Network/virtualNetworks/subnets/write",
#          "Microsoft.Network/virtualNetworks/subnets/join/action",
#          "Microsoft.Network/virtualNetworks/subnets/delete",
#          "Microsoft.Network/networkSecurityGroups/read",
#          "Microsoft.Network/networkSecurityGroups/write",
#          "Microsoft.Network/networkSecurityGroups/join/action",
#          "Microsoft.Network/networkSecurityGroups/securityRules/read",
#          "Microsoft.Network/networkSecurityGroups/securityRules/write",
#          "Microsoft.Network/networkSecurityGroups/securityRules/delete",
#          "Microsoft.Network/networkSecurityGroups/delete",
#          "Microsoft.Network/publicIPAddresses/read",
#          "Microsoft.Network/publicIPAddresses/write",
#          "Microsoft.Network/publicIPAddresses/delete",
#          "Microsoft.Network/publicIPAddresses/join/action",
#          "Microsoft.Compute/proximityPlacementGroups/*",
#          "Microsoft.Network/networkInterfaces/read",
#          "Microsoft.Network/networkInterfaces/write",
#          "Microsoft.Network/networkInterfaces/join/action",
#          "Microsoft.Network/networkInterfaces/delete",
#          "Microsoft.Resources/subscriptions/resourceGroups/read",
#          "Microsoft.Resources/subscriptions/resourceGroups/write",
#          "Microsoft.Compute/virtualMachines/read",
#          "Microsoft.Compute/virtualMachines/write",
#          "Microsoft.Compute/virtualMachines/delete",
#          "Microsoft.Compute/disks/read",
#          "Microsoft.Compute/disks/write",
#          "Microsoft.Compute/disks/delete",
#        ],
#        notActions     = [],
#        dataActions    = [],
#        notDataActions = []
#      }
#      assignable_scopes = [
#        "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"
#      ]
#    }
#
#    "${var.prefix}_custom_role_using_vnet" = {
#      description = "Custom Role to allow create weka resources, with existing network under resource group ${var.rg_name}"
#      scope       = "${data.azurerm_subscription.primary.id}"
#      permissions = {
#        actions = [
#          "Microsoft.Network/virtualNetworks/read",
#          "Microsoft.Network/virtualNetworks/subnets/read",
#          "Microsoft.Network/virtualNetworks/subnets/join/action",
#          "Microsoft.Network/networkSecurityGroups/securityRules/read",
#          "Microsoft.Network/publicIPAddresses/read",
#          "Microsoft.Network/publicIPAddresses/write",
#          "Microsoft.Network/publicIPAddresses/delete",
#          "Microsoft.Network/publicIPAddresses/join/action",
#          "Microsoft.Compute/proximityPlacementGroups/read",
#          "Microsoft.Compute/proximityPlacementGroups/write",
#          "Microsoft.Compute/proximityPlacementGroups/delete",
#          "Microsoft.Network/networkInterfaces/read",
#          "Microsoft.Network/networkInterfaces/write",
#          "Microsoft.Network/networkInterfaces/join/action",
#          "Microsoft.Network/networkInterfaces/delete",
#          "Microsoft.Resources/subscriptions/resourceGroups/read",
#          "Microsoft.Resources/subscriptions/resourceGroups/write",
#          "Microsoft.Compute/virtualMachines/read",
#          "Microsoft.Compute/virtualMachines/write",
#          "Microsoft.Compute/virtualMachines/delete",
#          "Microsoft.Compute/disks/read",
#          "Microsoft.Compute/disks/write",
#          "Microsoft.Compute/disks/delete"
#        ],
#        notActions     = [],
#        dataActions    = [],
#        notDataActions = []
#      }
#      assignable_scopes = [
#        "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}",
#        "${data.azurerm_subscription.primary.id}/resourceGroups/${var.vnet_rg_name}"
#
#      ]
#    }
#  }
#  role_name = var.use_network == true ? "${var.prefix}_custom_role_using_vnet" : "${var.prefix}_custom_role"
#}
#
#resource "azuread_application" "app" {
#  display_name = "${var.prefix}-app"
#  owners       = [data.azuread_client_config.current.object_id]
#}
#
#resource "azuread_service_principal" "sp" {
#  application_id = azuread_application.app.application_id
#  owners         = [data.azuread_client_config.current.object_id]
#}
#
#resource "azuread_service_principal_password" "sp_password" {
#  service_principal_id = azuread_service_principal.sp.object_id
#}
#
#resource "azurerm_role_definition" "custom_role" {
#  name        = local.role_name
#  scope       = local.custom_role_definitions[local.role_name]["scope"]
#  description = local.custom_role_definitions[local.role_name]["description"]
#
#  permissions {
#    actions          = lookup(local.custom_role_definitions[local.role_name]["permissions"], "actions", [])
#    not_actions      = lookup(local.custom_role_definitions[local.role_name]["permissions"], "notActions", [])
#    data_actions     = lookup(local.custom_role_definitions[local.role_name]["permissions"], "dataActions", [])
#    not_data_actions = lookup(local.custom_role_definitions[local.role_name]["permissions"], "notDataActions", [])
#  }
#  assignable_scopes = lookup(local.custom_role_definitions[local.role_name]["permissions"], "assignable_scopes", [])
#}
#
#resource "azurerm_role_assignment" "role_assignment" {
#  principal_id       = azuread_service_principal.sp.object_id
#  role_definition_id = azurerm_role_definition.custom_role.role_definition_resource_id
#  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.rg_name}"
#  depends_on         = [azurerm_role_definition.custom_role]
#}
#
#
#resource "azurerm_role_assignment" "role_assignment_to_vnet_rg" {
#  count              = var.use_network ? 1 : 0
#  principal_id       = azuread_service_principal.sp.object_id
#  scope              = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.vnet_rg_name}"
#  role_definition_id = azurerm_role_definition.custom_role.role_definition_resource_id
#  depends_on         = [azurerm_role_definition.custom_role]
#}