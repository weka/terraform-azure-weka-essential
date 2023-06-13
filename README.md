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
  source            = "git@github.com:weka/terraform-azure-weka-essential.git"
  prefix            = "essential"
  rg_name           = "example"
  cluster_name      = "test"
  instance_type     = "Standard_L8s_v3"
  cluster_size      = 6
  get_weka_io_token = "..."
  vnet_name         = "essential-vnet"
  subnet            = "essential-subnet"
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
This weka deployment can use exiting network, or create network resources (vmet, subnet, security group) automatically.
<br>We provided a file named `vars.auto.tfvars` with example of the variables that should be supplied.
<br>In case you want to use an existing network, you **must** provide network params.
<br>**Example**:
```hcl
vnet_name           = "essential-vnet"
subnet              = "essential-subnet"
```
**If you don't pass these params, we will automatically create the network resources.**
### Weka deployment using exiting network full example:
`vars.auto.tfvars` :
```hcl
subscription_id     = "..."
get_weka_io_token   = "..."
prefix              = "essential"
rg_name             = "example"
cluster_name        = "test"
instance_type       = "Standard_L8s_v3"
cluster_size        = 6
vnet_name           = "essential-vnet"
subnet              = "essential-subnet"
```

### Weka deployment creating network resources (vnet, subnet, security group) full example:
Note: the network params from above are not supplied here
`vars.auto.tfvars` :
```hcl
subscription_id     = "..."
get_weka_io_token   = "..."
prefix              = "essential"
rg_name             = "example"
cluster_name        = "test"
instance_type       = "Standard_L8s_v3"
cluster_size        = 6
```

### Private network deployment:
#### To avoid public ip assignment:
```hcl
assign_public_ip   = false
``` 
#### Vms with no internet outbound:
In case your vms don't have internet access, you should supply weka tar file url and apt repo url:
```hcl
apt_repo_url = "..."
install_weka_url = "..."
```
## Ssh keys
The username for ssh into vms is `weka`.
We allow passing exising public key string:
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
| [azurerm_virtual_machine_data_disk_attachment.clusterize_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.vm_disk_attachment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) | data source |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | The range of IP addresses the virtual network uses. Relevant only for network creation mode, where subnets weren't supplied. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_apt_repo_url"></a> [apt\_repo\_url](#input\_apt\_repo\_url) | The URL of the apt private repository. | `string` | `""` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Determines whether to assign public ip. | `bool` | `true` | no |
| <a name="input_blob_obs_access_key"></a> [blob\_obs\_access\_key](#input\_blob\_obs\_access\_key) | The access key of the existing Blob object store container. | `string` | `""` | no |
| <a name="input_client_instance_type"></a> [client\_instance\_type](#input\_client\_instance\_type) | The client virtual machine type (sku) to deploy. | `string` | `"Standard_D8_v5"` | no |
| <a name="input_client_nics_num"></a> [client\_nics\_num](#input\_client\_nics\_num) | The client NICs number. | `string` | `2` | no |
| <a name="input_clients_number"></a> [clients\_number](#input\_clients\_number) | The number of client virtual machines to deploy. | `number` | `0` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name. | `string` | `"poc"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | The number of virtual machines to deploy. | `number` | `6` | no |
| <a name="input_container_number_map"></a> [container\_number\_map](#input\_container\_number\_map) | Maps the number of objects and memory size per machine type. | <pre>map(object({<br>    compute  = number<br>    drive    = number<br>    frontend = number<br>    nvme     = number<br>    nics     = number<br>    memory   = string<br>  }))</pre> | <pre>{<br>  "Standard_L16s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": "72GB",<br>    "nics": 8,<br>    "nvme": 2<br>  },<br>  "Standard_L32s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": "189GB",<br>    "nics": 8,<br>    "nvme": 4<br>  },<br>  "Standard_L48s_v3": {<br>    "compute": 3,<br>    "drive": 3,<br>    "frontend": 1,<br>    "memory": "306GB",<br>    "nics": 8,<br>    "nvme": 6<br>  },<br>  "Standard_L64s_v3": {<br>    "compute": 4,<br>    "drive": 2,<br>    "frontend": 1,<br>    "memory": "418GB",<br>    "nics": 8,<br>    "nvme": 8<br>  },<br>  "Standard_L8s_v3": {<br>    "compute": 1,<br>    "drive": 1,<br>    "frontend": 1,<br>    "memory": "31GB",<br>    "nics": 4,<br>    "nvme": 1<br>  }<br>}</pre> | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | The default disk size. | `number` | `48` | no |
| <a name="input_get_weka_io_token"></a> [get\_weka\_io\_token](#input\_get\_weka\_io\_token) | The token to download the Weka release from get.weka.io. | `string` | n/a | yes |
| <a name="input_hotspare"></a> [hotspare](#input\_hotspare) | Hot-spare value. | `number` | `1` | no |
| <a name="input_install_cluster_dpdk"></a> [install\_cluster\_dpdk](#input\_install\_cluster\_dpdk) | Install weka cluster with DPDK | `bool` | `true` | no |
| <a name="input_install_weka_url"></a> [install\_weka\_url](#input\_install\_weka\_url) | The URL of the Weka release download tar file. | `string` | `""` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The virtual machine type (sku) to deploy. | `string` | `"Standard_L8s_v3"` | no |
| <a name="input_mount_clients_dpdk"></a> [mount\_clients\_dpdk](#input\_mount\_clients\_dpdk) | Mount weka clients in DPDK mode | `bool` | `true` | no |
| <a name="input_obs_container_name"></a> [obs\_container\_name](#input\_obs\_container\_name) | Name of obs container name | `string` | `""` | no |
| <a name="input_obs_name"></a> [obs\_name](#input\_obs\_name) | Name of obs storage account | `string` | `""` | no |
| <a name="input_os_type"></a> [os\_type](#input\_os\_type) | Type of os, The default is ubuntu | `string` | `"ubuntu"` | no |
| <a name="input_placement_group_id"></a> [placement\_group\_id](#input\_placement\_group\_id) | Proximity placement group to use for the vmss. If not passed, will be created automatically. | `string` | `""` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix for all the resource names. For example, the prefix for your system name. | `string` | `"weka"` | no |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | Cluster data protection level. | `number` | `2` | no |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | A predefined resource group in the Azure subscription. | `string` | n/a | yes |
| <a name="input_set_obs"></a> [set\_obs](#input\_set\_obs) | Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration. | `bool` | `false` | no |
| <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id) | Use weka custom image, ubuntu 20.04 with kernel 5.4 and ofed 5.8-1.1.2.1 | `string` | `"/communityGalleries/WekaIO-d7d3f308-d5a1-4c45-8e8a-818aed57375a/images/ubuntu20.04/versions/latest"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Ssh public key to pass to vms. | `string` | `null` | no |
| <a name="input_stripe_width"></a> [stripe\_width](#input\_stripe\_width) | Stripe width = cluster\_size - protection\_level - 1 (by default). | `number` | `-1` | no |
| <a name="input_subnet"></a> [subnet](#input\_subnet) | The subnet name. | `string` | `""` | no |
| <a name="input_subnet_prefix"></a> [subnet\_prefix](#input\_subnet\_prefix) | Prefix to use subnet.<br>    Relevant only for network creation mode, where subnet wasn't supplied. | `string` | `"10.0.0.0/24"` | no |
| <a name="input_tags_map"></a> [tags\_map](#input\_tags\_map) | A map of tags to assign the same metadata to all resources in the environment. Format: key:value. | `map(string)` | <pre>{<br>  "creator": "tf",<br>  "env": "dev"<br>}</pre> | no |
| <a name="input_tiering_ssd_percent"></a> [tiering\_ssd\_percent](#input\_tiering\_ssd\_percent) | When set\_obs\_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering\_ssd\_percent is set to 20, the total available capacity is 100GB. | `number` | `20` | no |
| <a name="input_traces_per_ionode"></a> [traces\_per\_ionode](#input\_traces\_per\_ionode) | The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes. | `number` | `10` | no |
| <a name="input_vm_username"></a> [vm\_username](#input\_vm\_username) | The user name for logging in to the virtual machines. | `string` | `"weka"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | The virtual network name. | `string` | `""` | no |
| <a name="input_vnet_rg_name"></a> [vnet\_rg\_name](#input\_vnet\_rg\_name) | Resource group name of vnet | `string` | `""` | no |
| <a name="input_weka_version"></a> [weka\_version](#input\_weka\_version) | The Weka version to deploy. | `string` | `"4.2.0.134-azuredk"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_ips"></a> [backend\_ips](#output\_backend\_ips) | If 'assign\_public\_ip' is set to true, it will output backends public ips, otherwise private ips. |
| <a name="output_client_ips"></a> [client\_ips](#output\_client\_ips) | If 'assign\_public\_ip' is set to true, it will output clients public ips, otherwise private ips. |
| <a name="output_private_ssh_key"></a> [private\_ssh\_key](#output\_private\_ssh\_key) | private\_ssh\_key:  If 'ssh\_public\_key' is set to null, it will output the private ssh key location. |
<!-- END_TF_DOCS -->
