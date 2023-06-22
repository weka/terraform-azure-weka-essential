provider "azurerm" {
  subscription_id = var.subscription_id
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

module "weka_deployment" {
  source            = "../.."
  prefix            = var.prefix
  rg_name           = var.rg_name
  cluster_name      = var.cluster_name
  instance_type     = var.instance_type
  cluster_size      = var.cluster_size
  get_weka_io_token = var.get_weka_io_token
}

output "weka_deployment_output" {
  value = module.weka_deployment
}
