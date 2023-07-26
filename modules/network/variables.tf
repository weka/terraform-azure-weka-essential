variable "prefix" {
  type = string
  description = "The prefix for all the resource names. For example, the prefix for your system name."
  default = "weka"
}

variable "rg_name" {
  type = string
  description =  "A predefined resource group in the Azure subscription for creating the vnet in."
}

variable "address_space" {
  type = string
  description = "The range of IP addresses the virtual network uses."
}

variable "subnet_prefix" {
  type = string
  description = "Address prefix to use for the subnet."
}

variable "tags_map" {
  type = map(string)
  default = {"weka_deployment": "azure-essential"}
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value."
}

variable "sg_ssh_range" {
  type        = list(string)
  description = "A list of IP addresses that can use ssh connection with a public network deployment."
  default = []
}
