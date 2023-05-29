variable "rg_name" {
  type = string
  description = "A predefined resource group in the Azure subscription."
}

variable "subnet_id" {
  type = string
  description = "The subnet id to use for storage account endpoint."
}


variable "private_dns_zone_id" {
  type = string
  description = "Private dns zone id."
}

variable "obs_name" {
  type = string
  default = ""
  description = "Name of obs storage account"
}

variable "obs_container_name" {
  type = string
  default = ""
  description = "Name of obs container name"
}