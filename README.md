# Azure-weka deployment Terraform package
Essential weka deployment.
<br>Creates vms and proximity placement group. Proximity placement group id can be passed and then it will not be created.
<br>The deployment can use existing network or create vnet/subnet/security groups.
- This deployment was created for essential weka deployment with minimum permissions.
- This deployment doesn't support auto-scaling.
- If you wish to review our full solution you can find it [here](https://github.com/weka/terraform-azure-weka)

## Usage example
```hcl
provider "azurerm" {
  subscription_id = "..."
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

module weka_deployment {
  source            = "weka/weka-essential/azure"
  version           = "1.0.3"
  prefix            = "essential"
  rg_name           = "example"
  cluster_name      = "test"
  instance_type     = "Standard_L8s_v3"
  cluster_size      = 6
  get_weka_io_token = "..."
  vnet_name         = "essential-vnet"
  subnet_name       = "essential-subnet"
}

output "weka_deployment_output" {
  value = module.weka_deployment
}
```

## Weke deployment prerequisites:
- vnet
- subnet

## Resource group
We have 2 variables that define resource group:
- rg_name
- vnet_rg_name
#### rg_name:
The resource group were weka cluster and all necessary resources will be deployed.
#### vnet_rg_name:
The resource group of the vnet and subnet.
<br>If `vnet_rg_name` isn't set by the user, we assume that the
vnet and subnet resource group is the as the weka deployment resource group.
<br> i.e we assume `vnet_rg_name = rg_name`

## Network deployment options
This weka deployment can use existing network, or create network resources (vmet, subnet, security group) automatically.
<br>Check our [examples](examples).
<br>In case you want to use an existing network, you **must** provide network params.
<br>**Example**:
```hcl
vnet_name           = "essential-vnet"
subnet_name         = "essential-subnet"
```
**If you don't pass these params, we will automatically create the network resources.**
### Weka deployment using existing network full example:
```hcl
module "weka_deployment" {
  source            = "weka/weka-essential/azure"
  version           = "1.0.0"
  prefix            = "essential"
  rg_name           = "example"
  cluster_name      = "test"
  instance_type     = "Standard_L8s_v3"
  cluster_size      = 6
  get_weka_io_token = "..."
  vnet_name         = "essential-vnet"
  subnet_name       = "essential-subnet"
}
```

### Weka deployment creating network resources (vnet, subnet, security group) full example:
Note: the network params from above are not supplied here:
```hcl
module "weka_deployment" {
  source            = "git@github.com:weka/terraform-azure-weka-essential.git"
  prefix            = "essential"
  rg_name           = "example"
  cluster_name      = "test"
  instance_type     = "Standard_L8s_v3"
  cluster_size      = 6
  get_weka_io_token = "..."
}
```

### Private network deployment:
#### To enable public ip assignment:
```hcl
assign_public_ip   = true
``` 
#### Vms with no internet outbound:
In case your vms don't have internet access, you should supply weka tar file url and apt repo url:
```hcl
apt_repo_url = "..."
install_weka_url = "..."
```
## Ssh keys
The username for ssh into vms is `weka`.
We allow passing existing public key string:
```hcl
ssh_public_key = "..."
```
If public key isn't passed we will create it for you and store the private key locally under `/tmp`
Names will be:
```
/tmp/${prefix}-${cluster_name}-public-key.pub
/tmp/${prefix}-${cluster_name}-private-key.pem
```
## OBS
We support tiering to blob container.
In order to setup tiering, you must supply the following variables:
```hcl
set_obs = true
obs_name = "..."
obs_container_name = "..."
blob_obs_access_key = "..."
```
In addition, you can supply (and override our default):
```hcl
tiering_ssd_percent = VALUE
```
## Clients
We support creating clients that will be mounted automatically to the cluster.
<br>In order to create clients you need to provide the number of clients you want (by default the number is 0),
for example:
```hcl
clients_number = 2
```
This will automatically create 2 clients.
<br>In addition you can supply these optional variables:
```hcl
client_instance_type = "Standard_D4_v4"
client_nics_num = DESIRED_NUM
```
### Mounting clients in udp mode
In order to mount clients in udp mode you should pass the following param (in addition to the above):
```hcl
mount_clients_dpdk = false
```

## Protocol gateways
We allow creating protocol gateway instances (stateful clients) for NFS / SMB protocols support.

To create protocol gateway instances you need to set the number of such instances (by default the number is 0):
```hcl
protocol_gateways_number = 3
```
You can also provide Azure instance type which will be used for gateway instances:
```hcl
protocol_gateway_instance_type = "Standard_D8_v5"
```
By default the **NFS** protocol will be configured on the gateway instances.  
NFS setup requires at least 1 instance.

To configure **SMB / SMBW** instead, you need to set the variables:
```hcl
protocol_gateways_number = 3
protocol                 = "SMB"
smbw_enabled             = true  // in case of SMB-W setup
smb_domain_name          = "qa.wekatest.io"
```
To join an SMB cluster in Active Directory, need to run manually command:

`weka smb domain join <smb_domain_username> <smb_domain_password> [--server smb_server_name]`.  

</br>Minimal number of instances required for SMB is 3.

## Weka custom image
As you can see via `source_image_id` variable, we use our own custom image.
This is a community image that we created and uploaded to azure.
In case you would like to view how we created the image you can find it [here](https://github.com/weka/terraform-azure-weka-custom-image).
You can as well create it on your own subscription and use it.
## Terraform output
In the output you will get the cluster backends (and clients if you asked for) ips.
<br>If `assign_public_ip` is set to `true` you will get a list of public ips, otherwise a list of private ips.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.7 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.43.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 3.43.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_clients"></a> [clients](#module\_clients) | ./modules/clients | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_nfs_protocol_gateways"></a> [nfs\_protocol\_gateways](#module\_nfs\_protocol\_gateways) | ./modules/protocol_gateways | n/a |
| <a name="module_smb_protocol_gateways"></a> [smb\_protocol\_gateways](#module\_smb\_protocol\_gateways) | ./modules/protocol_gateways | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_linux_virtual_machine.clusterizing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_linux_virtual_machine.vms](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_managed_disk.clusterize_disks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_managed_disk.vm_disks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_network_interface.private_first_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface.private_nics](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface.public_first_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_proximity_placement_group.ppg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/proximity_placement_group) | resource |
| [azurerm_public_ip.publicIp](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_role_assignment.clusterizing-vm-assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.vms-assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.clusterize_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.vm_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) | data source |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_storage_account.sa](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | The range of IP addresses the virtual network uses. Relevant only for network creation mode, where subnets weren't supplied. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_allow_ssh_cidrs"></a> [allow\_ssh\_cidrs](#input\_allow\_ssh\_cidrs) | Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG | `list(string)` | `[]` | no |
| <a name="input_allow_weka_api_cidrs"></a> [allow\_weka\_api\_cidrs](#input\_allow\_weka\_api\_cidrs) | Allow connection to port 14000 on weka backends and ALB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC | `list(string)` | `[]` | no |
| <a name="input_apt_repo_url"></a> [apt\_repo\_url](#input\_apt\_repo\_url) | The URL of the apt private repository. | `string` | `""` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways | `bool` | `true` | no |
| <a name="input_client_frontend_cores"></a> [client\_frontend\_cores](#input\_client\_frontend\_cores) | Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC | `number` | `1` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client virtual machine type (sku) to deploy. | `string` | `"Standard_D8_v5"` | no |
| <a name="input_client_placement_group_id"></a> [client\_placement\_group\_id](#input\_client\_placement\_group\_id) | The client instances placement group id. Backend placement group can be reused. If not specified placement group will be created automatically | `string` | `""` | no |
| <a name="input_client_source_image_id"></a> [client\_source\_image\_id](#input\_client\_source\_image\_id) | Use weka custom image, ubuntu 20.04 with kernel 5.4 and ofed 5.8-1.1.2.1 | `string` | `"/communityGalleries/WekaIO-d7d3f308-d5a1-4c45-8e8a-818aed57375a/images/ubuntu20.04/versions/latest"` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client virtual machines to deploy. | `number` | `0` | no |
| <a name="input_clients_use_dpdk"></a> [clients\_use\_dpdk](#input\_clients\_use\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name. | `string` | `"poc"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | The number of virtual machines to deploy. | `number` | `6` | no |
| <a name="input_containers_config_map"></a> [containers\_config\_map](#input\_containers\_config\_map) | Maps the number of cores (per container type) and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nvme     = number<br>    nics     = number<br>    memory   = list(string)<br>  }))</pre> | <pre>{<br>  "Standard_L16s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "79GB",<br>      "72GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 2<br>  },<br>  "Standard_L32s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "197GB",<br>      "189GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 4<br>  },<br>  "Standard_L48s_v3": {<br>    "compute": 3,<br>    "drive": 3,<br>    "frontend": 1,<br>    "memory": [<br>      "314GB",<br>      "306GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 6<br>  },<br>  "Standard_L64s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": [<br>      "357GB",<br>      "384GB"<br>    ],<br>    "nics": 8,<br>    "nvme": 8<br>  },<br>  "Standard_L8s_v3": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": [<br>      "33GB",<br>      "31GB"<br>    ],<br>    "nics": 4,<br>    "nvme": 1<br>  }<br>}</pre> | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The default disk size. | `number` | `48` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Number of hotspares to set on weka cluster. Refer to https://docs.weka.io/overview/ssd-capacity-management#hot-spare | `number` | `1` | no |
| <a name="input_install_cluster_dpdk"></a> [install\_cluster\_dpdk](#input\_install\_cluster\_dpdk) | Install weka cluster with DPDK | `bool` | `true` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release. Supports path to weka tar file or installation script. | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"Standard_L8s_v3"` | no |
| <a name="input_nfs_protocol_gateway_disk_size"></a> [nfs\_protocol\_gateway\_disk\_size](#input\_nfs\_protocol\_gateway\_disk\_size) | The protocol gateways' default disk size. | `number` | `48` | no |
| <a name="input_nfs_protocol_gateway_fe_cores_num"></a> [nfs\_protocol\_gateway\_fe\_cores\_num](#input\_nfs\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on single protocol gateway machine. | `number` | `1` | no |
| <a name="input_nfs_protocol_gateway_instance_type"></a> [nfs\_protocol\_gateway\_instance\_type](#input\_nfs\_protocol\_gateway\_instance\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"Standard_D8_v5"` | no |
| <a name="input_nfs_protocol_gateway_secondary_ips_per_nic"></a> [nfs\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_nfs\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_nfs_protocol_gateways_number"></a> [nfs\_protocol\_gateways\_number](#input\_nfs\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_nfs_setup_protocol"></a> [nfs\_setup\_protocol](#input\_nfs\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | Type of os, The default is ubuntu | `string` | `"ubuntu"` | no |
| <a name="input_placement_group_id"></a> [placement\_group\_id](#input\_placement\_group\_id) | Proximity placement group to use for the vmss. If not passed, will be created automatically. | `string` | `""` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix for all the resource names. For example, the prefix for your system name. | `string` | `"weka"` | no |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | A predefined resource group in the Azure subscription. | `string` | n/a | yes |
| <a name="input_set_dedicated_fe_container"></a> [set\_dedicated\_fe\_container](#input\_set\_dedicated\_fe\_container) | Create cluster with FE containers | `bool` | `true` | no |
| <a name="input_smb_cluster_name"></a> [smb\_cluster\_name](#input\_smb\_cluster\_name) | The name of the SMB setup. | `string` | `"Weka-SMB"` | no |
| <a name="input_smb_domain_name"></a> [smb\_domain\_name](#input\_smb\_domain\_name) | The domain to join the SMB cluster to. | `string` | `""` | no |
| <a name="input_smb_protocol_gateway_disk_size"></a> [smb\_protocol\_gateway\_disk\_size](#input\_smb\_protocol\_gateway\_disk\_size) | The protocol gateways' default disk size. | `number` | `48` | no |
| <a name="input_smb_protocol_gateway_fe_cores_num"></a> [smb\_protocol\_gateway\_fe\_cores\_num](#input\_smb\_protocol\_gateway\_fe\_cores\_num) | The number of frontend cores on single protocol gateway machine. | `number` | `1` | no |
| <a name="input_smb_protocol_gateway_instance_type"></a> [smb\_protocol\_gateway\_instance\_type](#input\_smb\_protocol\_gateway\_instance\_type) | The protocol gateways' virtual machine type (sku) to deploy. | `string` | `"Standard_D8_v5"` | no |
| <a name="input_smb_protocol_gateway_secondary_ips_per_nic"></a> [smb\_protocol\_gateway\_secondary\_ips\_per\_nic](#input\_smb\_protocol\_gateway\_secondary\_ips\_per\_nic) | Number of secondary IPs per single NIC per protocol gateway virtual machine. | `number` | `3` | no |
| <a name="input_smb_protocol_gateways_number"></a> [smb\_protocol\_gateways\_number](#input\_smb\_protocol\_gateways\_number) | The number of protocol gateway virtual machines to deploy. | `number` | `0` | no |
| <a name="input_smb_setup_protocol"></a> [smb\_setup\_protocol](#input\_smb\_setup\_protocol) | Config protocol, default if false | `bool` | `false` | no |
| <a name="input_smbw_enabled"></a> [smbw\_enabled](#input\_smbw\_enabled) | Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup. | `bool` | `true` | no |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | Use weka custom image, ubuntu 20.04 with kernel 5.4 and ofed 5.8-1.1.2.1 | `string` | `"/communityGalleries/WekaIO-d7d3f308-d5a1-4c45-8e8a-818aed57375a/images/ubuntu20.04/versions/latest"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | `null` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | The subnet name. | `string` | `""` | no |
| <a name="input_subnet_prefix"></a> [subnet\_prefix](#input\_subnet\_prefix) | Prefix to use subnet.<br>    Relevant only for network creation mode, where subnet wasn't supplied. | `string` | `"10.0.0.0/24"` | no |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | <pre>{<br>  "creator": "tf",<br>  "env": "dev"<br>}</pre> | no |
| <a name="input_tiering_blob_obs_access_key"></a> [tiering\_blob\_obs\_access\_key](#input\_tiering\_blob\_obs\_access\_key) | The access key of the existing Blob object store container. | `string` | `""` | no |
| <a name="input_tiering_enable_obs"></a> [tiering\_enable\_obs](#input\_tiering\_enable\_obs) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_tiering_obs_container_name"></a> [tiering\_obs\_container\_name](#input\_tiering\_obs\_container\_name) | Name of obs container name | `string` | `""` | no |
| <a name="input_tiering_obs_name"></a> [tiering\_obs\_name](#input\_tiering\_obs\_name) | Name of obs storage account | `string` | `""` | no |
| <a name="input_tiering_ssd_percent"></a> [tiering\_ssd\_percent](#input\_tiering\_ssd\_percent) | When set\_obs\_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering\_ssd\_percent is set to 20, the total available capacity is 100GB. | `number` | `20` | no |
| <a name="input_traces_per_ionode"></a> [traces\_per\_ionode](#input\_traces\_per\_ionode) | The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes. | `number` | `10` | no |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | Provided as part of output for automated use of terraform, in case of custom AMI and automated use of outputs replace this with user that should be used for ssh connection | `string` | `"weka"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | The virtual network name. | `string` | `""` | no |
| <a name="input_vnet_rg_name"></a> [vnet\_rg\_name](#input\_vnet\_rg\_name) | Resource group name of vnet | `string` | `""` | no |
| <a name="input_weka_home_url"></a> [weka\_home\_url](#input\_weka\_home\_url) | Weka Home url | `string` | `""` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | The Weka version to deploy. | `string` | `"4.2.7.64"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | The zone in which the resources should be created. | `string` | `"1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_ips"></a> [backend\_ips](#output\_backend\_ips) | If 'assign\_public\_ip' is set to true, it will output backends public ips, otherwise private ips. |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | If 'assign\_public\_ip' is set to true, it will output clients public ips, otherwise private ips. |
| <a name="output_nfs_protocol_gateway_ips"></a> [nfs\_protocol\_gateway\_ips](#output\_nfs\_protocol\_gateway\_ips) | If 'private\_network' is set to false, it will output nfs protocol gateway public ips, otherwise private ips. |
| <a name="output_private_ssh_key"></a> [private\_ssh\_key](#output\_private\_ssh\_key) | private\_ssh\_key:  If 'ssh\_public\_key' is set to null, it will output the private ssh key location. |
| <a name="output_smb_protocol_gateway_ips"></a> [smb\_protocol\_gateway\_ips](#output\_smb\_protocol\_gateway\_ips) | If 'private\_network' is set to false, it will output smb protocol gateway public ips, otherwise private ips. |
| <a name="output_vm_username"></a> [vm\_username](#output\_vm\_username) | Provided as part of output for automated use of terraform, ssh user to weka cluster vm |
<!-- END_TF_DOCS -->
