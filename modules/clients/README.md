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
| [azurerm_linux_virtual_machine.custom_image_vms](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_linux_virtual_machine.default_image_vms](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.client_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface.primary_client_nic_private](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface.primary_client_nic_public](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_public_ip.public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apt_repo_url"></a> [apt\_repo\_url](#input\_apt\_repo\_url) | The URL of the apt private repository. | `string` | `""` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_backend_ip"></a> [backend\_ip](#input\_backend\_ip) | n/a | `string` | n/a | yes |
| <a name="input_clients_name"></a> [clients\_name](#input\_clients\_name) | The clients name. | `string` | n/a | yes |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of virtual machines to deploy. | `number` | `2` | no |
| <a name="input_custom_image_id"></a> [custom\_image\_id](#input\_custom\_image\_id) | Custom image id | `string` | `null` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_install_ofed"></a> [install\_ofed](#input\_install\_ofed) | Install ofed for weka cluster with dpdk configuration | `bool` | `true` | no |
| <a name="input_install_ofed_url"></a> [install\_ofed\_url](#input\_install\_ofed\_url) | The URL of the Blob with the OFED tgz file. | `string` | `""` | no |
| <a name="input_install_weka_template_file"></a> [install\_weka\_template\_file](#input\_install\_weka\_template\_file) | install\_weka\_template file path | `string` | n/a | yes |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release download tar file. | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"Standard_D4_v4"` | no |
| <a name="input_linux_vm_image"></a> [linux\_vm\_image](#input\_linux\_vm\_image) | The default azure vm image reference. | `map(string)` | <pre>{<br>  "ofed": "ubuntu20.04",<br>  "offer": "0001-com-ubuntu-server-focal",<br>  "publisher": "Canonical",<br>  "sku": "20_04-lts-gen2",<br>  "version": "latest"<br>}</pre> | no |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Install weka cluster with DPDK | `bool` | `true` | no |
| <a name="input_nics"></a> [nics](#input\_nics) | Number of nics to set on each client vm | `number` | `2` | no |
| <a name="input_nics_map"></a> [nics\_map](#input\_nics\_map) | n/a | `map(number)` | <pre>{<br>  "Standard_L16s_v3": 8,<br>  "Standard_L8s_v3": 4<br>}</pre> | no |
| <a name="input_ofed_version"></a> [ofed\_version](#input\_ofed\_version) | The OFED driver version to for ubuntu 20. | `string` | `"5.8-1.1.2.1"` | no |
| <a name="input_ppg_id"></a> [ppg\_id](#input\_ppg\_id) | Placement proximity group id. | `string` | n/a | yes |
| <a name="input_preparation_template_file"></a> [preparation\_template\_file](#input\_preparation\_template\_file) | preparation\_template file path | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | A predefined resource group in the Azure subscription. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | The VM public key. If it is not set, the keys are auto-generated. | `string` | n/a | yes |
| <a name="input_subnets_name"></a> [subnets\_name](#input\_subnets\_name) | The subnet names list. | `list(string)` | n/a | yes |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The user name for logging in to the virtual machines. | `string` | `"weka"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | The virtual network name. | `string` | n/a | yes |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | The Weka version to deploy. | `string` | `"4.1.0.71"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client-ips"></a> [client-ips](#output\_client-ips) | n/a |
<!-- END_TF_DOCS -->
