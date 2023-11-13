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