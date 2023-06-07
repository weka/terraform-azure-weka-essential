variable "backend_ips" {
  type        = list(string)
  description = ""
}

variable "nics" {
  type        = number
  default     = 2
  description = "Number of nics to set on each client vm"
}

variable "linux_vm_image" {
  type        = map(string)
  description = "The default azure vm image reference."
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
    ofed      = "ubuntu20.04"
  }
}

variable "custom_image_id" {
  type        = string
  description = "Custom image id"
  default     = null
}

variable "rg_name" {
  type        = string
  description = "A predefined resource group in the Azure subscription."
}

variable "vm_username" {
  type        = string
  description = "The user name for logging in to the virtual machines."
  default     = "weka"
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy."
  default     = "Standard_D4_v4"
}

variable "vnet_name" {
  type        = string
  description = "The virtual network name."
}

variable "clients_name" {
  type        = string
  description = "The clients name."
}

variable "subnet_name" {
  type        = string
  description = "The subnet names."
}

variable "clients_number" {
  type        = number
  description = "The number of virtual machines to deploy."
  default     = 2
}

variable "ssh_public_key" {
  type        = string
  description = "The VM public key. If it is not set, the keys are auto-generated."
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

variable "apt_repo_url" {
  type        = string
  default     = ""
  description = "The URL of the apt private repository."
}

variable "preparation_template_file" {
  type        = string
  description = "preparation_template file path"
}

variable "mount_clients_dpdk" {
  type        = bool
  default     = true
  description = "Install weka cluster with DPDK"
}

variable "install_ofed" {
  type        = bool
  default     = true
  description = "Install ofed for weka cluster with dpdk configuration"
}

variable "nics_map" {
  type = map(number)
  default = {
    Standard_L8s_v3  = 4
    Standard_L16s_v3 = 8
  }
}

variable "ppg_id" {
  type        = string
  description = "Placement proximity group id."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "vnet_rg_name" {
  type        = string
  description = "Resource group name of vnet"
}