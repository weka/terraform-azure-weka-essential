<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dns"></a> [dns](#module\_dns) | ../modules/dns | n/a |
| <a name="module_network"></a> [network](#module\_network) | ../modules/network | n/a |
| <a name="module_obs"></a> [obs](#module\_obs) | ../modules/obs | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.write_obs_blob_key](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_storage_account.obs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_blob_obs_access_key_location"></a> [blob\_obs\_access\_key\_location](#output\_blob\_obs\_access\_key\_location) | n/a |
| <a name="output_obs_container_name"></a> [obs\_container\_name](#output\_obs\_container\_name) | n/a |
| <a name="output_obs_name"></a> [obs\_name](#output\_obs\_name) | n/a |
<!-- END_TF_DOCS -->