provider "azurerm" {
  subscription_id = "..."
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

module "weka_deployment" {
  source                = "../.."
  prefix                = "essential"
  rg_name               = "example"
  cluster_name          = "test"
  instance_type         = "Standard_L8s_v3"
  cluster_size          = 6
  get_weka_io_token     = "..."
  allow_ssh_ranges      = ["0.0.0.0/0"]
  allow_weka_api_ranges = ["0.0.0.0/0"]
}

output "weka_deployment_output" {
  value = module.weka_deployment
}
