<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_network_security_group.sg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.sg_public_ssh](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.sg_weka](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.sg-association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | The range of IP addresses the virtual network uses. | `string` | n/a | yes |
| <a name="input_allow_ssh_ranges"></a> [allow\_ssh\_ranges](#input\_allow\_ssh\_ranges) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_ranges"></a> [allow\_weka\_api\_ranges](#input\_allow\_weka\_api\_ranges) | Allow port 14000, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix for all the resource names. For example, the prefix for your system name. | `string` | `"weka"` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | A predefined resource group in the Azure subscription for creating the vnet in. | `string` | n/a | yes |
| <a name="input_subnet_prefix"></a> [subnet\_prefix](#input\_subnet\_prefix) | Address prefix to use for the subnet. | `string` | n/a | yes |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | <pre>{<br>  "weka_deployment": "azure-essential"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_subnet_name"></a> [subnet\_name](#output\_subnet\_name) | n/a |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | n/a |
<!-- END_TF_DOCS -->