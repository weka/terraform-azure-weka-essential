
variable "client_id" {
  type        = string
  description = "Client id of Service principal user"
}

variable "tenant_id" {
  type        = string
  description = "Tenant id"
}

variable "client_secret" {
  type        = string
  description = "Password of service principal user"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
}

variable "rg_name" {
  type        = string
  description = "Name of existing resource group"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "instance_type" {
  type        = string
  description = "The SKU which should be used for this virtual machine"
}

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"
}

variable "subscription_id" {
  type        = string
  description = "Subscription id for deployment"
}

variable "get_weka_io_token" {
  type        = string
  sensitive   = true
  description = "Get get.weka.io token for downloading weka"
}

