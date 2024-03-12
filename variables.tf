variable "prefix" {
  type        = string
  description = "The prefix for all the resource names. For example, the prefix for your system name."
  default     = "weka"
}

variable "rg_name" {
  type        = string
  description = "A predefined resource group in the Azure subscription."
}

variable "vnet_rg_name" {
  type        = string
  description = "Resource group name of vnet"
  default     = ""
}

variable "vm_username" {
  type        = string
  description = "Provided as part of output for automated use of terraform, in case of custom AMI and automated use of outputs replace this with user that should be used for ssh connection"
  default     = "weka"
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy."
  default     = "Standard_L8s_v3"
}

variable "vnet_name" {
  type        = string
  description = "The virtual network name."
  default     = ""
}

variable "subnet_name" {
  type        = string
  description = "The subnet name."
  default     = ""
}

variable "address_space" {
  type        = string
  description = "The range of IP addresses the virtual network uses. Relevant only for network creation mode, where subnets weren't supplied."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  type        = string
  description = <<EOF
    Prefix to use subnet.
    Relevant only for network creation mode, where subnet wasn't supplied.
  EOF
  default     = "10.0.0.0/24"
}

variable "cluster_size" {
  type        = number
  description = "The number of virtual machines to deploy."
  default     = 6

  validation {
    condition     = var.cluster_size >= 6
    error_message = "Cluster size should be at least 6."
  }
}

variable "os_type" {
  default     = "ubuntu"
  type        = string
  description = "Type of os, The default is ubuntu"
}

variable "source_image_id" {
  type        = string
  default     = "/communityGalleries/WekaIO-d7d3f308-d5a1-4c45-8e8a-818aed57375a/images/ubuntu20.04/versions/latest"
  description = "Use weka custom image, ubuntu 20.04 with kernel 5.4 and ofed 5.8-1.1.2.1"
}

variable "weka_version" {
  type        = string
  description = "The Weka version to deploy."
  default     = "4.2.9-1"
}

variable "get_weka_io_token" {
  type        = string
  description = "The token to download the Weka release from get.weka.io."
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "The cluster name."
  default     = "poc"
}

variable "tags_map" {
  type        = map(string)
  default     = { "env" : "dev", "creator" : "tf" }
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value."
}

variable "ssh_public_key" {
  type        = string
  description = "Ssh public key to pass to vms."
  default     = null
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways"
}

variable "containers_config_map" {
  # NOTE: compute = nics-drive-frontend-1
  type = map(object({
    compute  = number
    drive    = number
    frontend = number
    nvme     = number
    nics     = number
    memory   = list(string)
  }))
  description = "Maps the number of cores (per container type) and memory size per machine type."
  default = {
    Standard_L8s_v3 = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 1
      nics     = 4
      memory   = ["33GB", "31GB"]
    },
    Standard_L16s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 2
      nics     = 8
      memory   = ["79GB", "72GB"]
    },
    Standard_L32s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 4
      nics     = 8
      memory   = ["197GB", "189GB"]
    },
    Standard_L48s_v3 = {
      compute  = 3
      drive    = 3
      frontend = 1
      nvme     = 6
      nics     = 8
      memory   = ["314GB", "306GB"]
    },
    Standard_L64s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 8
      nics     = 8
      memory   = ["357GB", "384GB"]
    }
  }
  validation {
    condition     = alltrue([for m in flatten([for i in values(var.containers_config_map) : (flatten(i.memory))]) : tonumber(trimsuffix(m, "GB")) <= 384])
    error_message = "Compute memory can not be more then 384GB"
  }
}

variable "default_disk_size" {
  type        = number
  default     = 48
  description = "The default disk size."
}

variable "traces_per_ionode" {
  default     = 10
  type        = number
  description = "The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes."
}

variable "protection_level" {
  type        = number
  default     = 2
  description = "Cluster data protection level."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Allowed protection_level values: [2, 4]."
  }
}

variable "stripe_width" {
  type        = number
  default     = -1
  description = "Stripe width = cluster_size - protection_level - 1 (by default)."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "The stripe_width value can take values from 3 to 16."
  }
}

variable "hotspare" {
  type        = number
  default     = 1
  description = "Number of hotspares to set on weka cluster. Refer to https://docs.weka.io/overview/ssd-capacity-management#hot-spare"
}

variable "install_cluster_dpdk" {
  type        = bool
  default     = true
  description = "Install weka cluster with DPDK"
}

variable "set_dedicated_fe_container" {
  type        = bool
  default     = true
  description = "Create cluster with FE containers"
}

variable "placement_group_id" {
  type        = string
  default     = ""
  description = "Proximity placement group to use for the vmss. If not passed, will be created automatically."
}

variable "apt_repo_url" {
  type        = string
  default     = ""
  description = "The URL of the apt private repository."
}

variable "install_weka_url" {
  type        = string
  description = "The URL of the Weka release. Supports path to weka tar file or installation script."
  default     = ""
}

################################################## obs variables ###################################################
variable "tiering_enable_obs" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_obs_name" {
  type        = string
  default     = ""
  description = "Name of obs storage account"
}

variable "tiering_obs_container_name" {
  type        = string
  default     = ""
  description = "Name of obs container name"
}

variable "tiering_blob_obs_access_key" {
  type        = string
  description = "The access key of the existing Blob object store container."
  sensitive   = true
  default     = ""
}

variable "tiering_ssd_percent" {
  type        = number
  default     = 20
  description = "When set_obs_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering_ssd_percent is set to 20, the total available capacity is 100GB."
}

####################### clients ###########################
variable "clients_number" {
  type        = number
  description = "The number of client virtual machines to deploy."
  default     = 0
}

variable "client_instance_type" {
  type        = string
  description = "The client virtual machine type (sku) to deploy."
  default     = "Standard_D8_v5"
}

variable "client_frontend_cores" {
  type        = number
  description = "Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC"
  default     = 1
}

variable "clients_use_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

variable "client_source_image_id" {
  type        = string
  default     = "/communityGalleries/WekaIO-d7d3f308-d5a1-4c45-8e8a-818aed57375a/images/ubuntu20.04/versions/latest"
  description = "Use weka custom image, ubuntu 20.04 with kernel 5.4 and ofed 5.8-1.1.2.1"
}

variable "client_placement_group_id" {
  type        = string
  description = "The client instances placement group id. Backend placement group can be reused. If not specified placement group will be created automatically"
  default     = ""
}

variable "allow_ssh_cidrs" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_weka_api_cidrs" {
  type        = list(string)
  description = "Allow connection to port 14000 on weka backends and ALB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC"
  default     = []
}

variable "zone" {
  type        = string
  description = "The zone in which the resources should be created."
  default     = "1"
}

variable "weka_home_url" {
  type        = string
  description = "Weka Home url"
  default     = ""
}


############################################### nfs protocol gateways variables ###################################################
variable "nfs_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "nfs_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "nfs_protocol_gateway_instance_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "Standard_D8_v5"
}

variable "nfs_protocol_gateway_disk_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "nfs_protocol_gateway_fe_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "nfs_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

############################################### smb protocol gateways variables ###################################################
variable "smb_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "smb_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "smb_protocol_gateway_instance_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "Standard_D8_v5"
}

variable "smb_protocol_gateway_disk_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "smb_protocol_gateway_fe_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "smb_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

variable "smbw_enabled" {
  type        = bool
  default     = true
  description = "Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup."
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB setup."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 0
    error_message = "The SMB cluster name cannot be empty."
  }
}

variable "smb_domain_name" {
  type        = string
  description = "The domain to join the SMB cluster to."
  default     = ""
}

