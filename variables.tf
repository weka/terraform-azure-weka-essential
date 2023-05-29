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
  description = "The user name for logging in to the virtual machines."
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

variable "subnets" {
  type        = list(string)
  description = "The subnet names list."
  default     = []
}

variable "address_space" {
  type        = string
  description = "The range of IP addresses the virtual network uses. Relevant only for network creation mode, where subnets weren't supplied."
  default     = "10.0.0.0/16"
}

variable "subnet_prefixes" {
  type        = list(string)
  description = <<EOF
    A list of address prefixes to use for the subnet.
    Relevant only for network creation mode, where subnets weren't supplied.
    The number of subnets to use wil be determined according to the instance type"
  EOF
  default = [
    "10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24",
    "10.0.7.0/24"
  ]
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

variable "linux_vm_image" {
  type        = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
    ofed      = string
  }))
  description = "The default azure vm image reference."
  default     = {
    ubuntu = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts-gen2"
      version   = "latest"
      ofed      = "ubuntu20.04"
    }
    rocky = {
      publisher = "procomputers"
      offer     = "rocky-linux-8-gen2"
      sku       = "rocky-linux-8-gen2"
      version   = "8.7.20221203"
      ofed      = "rhle8.7"
    }
  }
}

variable "weka_version" {
  type        = string
  description = "The Weka version to deploy."
  default     = "4.2.0.126-azuredk"
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
  description = "Determines whether to assign public ip."
}

variable "ofed_version" {
  type        = string
  description = "The OFED driver version to for ubuntu 20."
  default     = "5.8-1.1.2.1"
}

variable "install_ofed_url" {
  type        = string
  description = "The URL of the Blob with the OFED tgz file."
  default     = ""
}

variable "container_number_map" {
  type = map(object({
    compute  = number
    drive    = number
    frontend = number
    nvme     = number
    nics     = number
    memory   = string
  }))
  description = "Maps the number of objects and memory size per machine type."
  default = {
    Standard_L8s_v3 = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 1
      nics     = 4
      memory   = "31GB"
    },
    Standard_L16s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 2
      nics     = 8
      memory   = "72GB"
    },
    Standard_L32s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 4
      nics     = 8
      memory   = "189GB"
    },
    Standard_L48s_v3 = {
      compute  = 3
      drive    = 3
      frontend = 1
      nvme     = 6
      nics     = 8
      memory   = "306GB"
    },
    Standard_L64s_v3 = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 8
      nics     = 8
      memory   = "418GB"
    }
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

variable "subscription_id" {
  type        = string
  description = "The subscription id for the deployment."
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
  description = "Hot-spare value."
}

variable "install_cluster_dpdk" {
  type        = bool
  default     = true
  description = "Install weka cluster with DPDK"
}

variable "install_ofed" {
  type        = bool
  default     = true
  description = "Install ofed for weka cluster with dpdk configuration"
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
  description = "The URL of the Weka release download tar file."
  default     = ""
}

################################################## obs variables ###################################################
variable "set_obs" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "obs_name" {
  type        = string
  default     = ""
  description = "Name of obs storage account"
}

variable "obs_container_name" {
  type        = string
  default     = ""
  description = "Name of obs container name"
}

variable "blob_obs_access_key" {
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

variable "clients_number" {
  type        = number
  description = "The number of client virtual machines to deploy."
  default     = 0
}

variable "client_instance_type" {
  type        = string
  description = "The client virtual machine type (sku) to deploy."
  default     = "Standard_D4_v4"
}

variable "client_nics_num" {
  type        = string
  description = "The client NICs number."
  default     = 2
}
