data "azurerm_client_config" "current" {}

module "network" {
  count                = var.subnet_name == "" ? 1 : 0
  source               = "./modules/network"
  prefix               = var.prefix
  rg_name              = local.vnet_rg_name
  address_space        = var.address_space
  subnet_prefix        = var.subnet_prefix
  allow_weka_api_cidrs = var.allow_weka_api_cidrs
  allow_ssh_cidrs      = var.allow_ssh_cidrs
}

module "clients" {
  count                        = var.clients_number > 0 ? 1 : 0
  source                       = "./modules/clients"
  rg_name                      = var.rg_name
  clients_name                 = "${var.prefix}-${var.cluster_name}-client"
  clients_number               = var.clients_number
  apt_repo_url                 = var.apt_repo_url
  clients_use_dpdk             = var.clients_use_dpdk
  subnet_name                  = data.azurerm_subnet.subnet.name
  source_image_id              = var.client_source_image_id
  vnet_name                    = local.vnet_name
  frontend_container_cores_num = var.clients_use_dpdk ? var.client_frontend_cores : 1
  instance_type                = var.client_instance_type
  backend_ips                  = local.first_nic_private_ips
  ssh_public_key               = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
  ppg_id                       = var.client_placement_group_id != "" ? var.client_placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  assign_public_ip             = var.assign_public_ip
  vnet_rg_name                 = local.vnet_rg_name
  depends_on                   = [azurerm_linux_virtual_machine.clusterizing, module.network]
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnet" {
  resource_group_name  = local.vnet_rg_name
  virtual_network_name = local.vnet_name
  name                 = var.subnet_name != "" ? var.subnet_name : module.network[0].subnet_name
  depends_on           = [module.network]
}

# ===================== SSH key ++++++++++++++++++++++++= #
resource "tls_private_key" "ssh_key" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  count           = var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].public_key_openssh
  filename        = local.ssh_public_key_path
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count           = var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].private_key_pem
  filename        = local.ssh_private_key_path
  file_permission = "0600"
}

locals {
  ssh_path              = "/tmp/${var.prefix}-${var.cluster_name}"
  ssh_public_key_path   = "${local.ssh_path}-public-key.pub"
  ssh_private_key_path  = "${local.ssh_path}-private-key.pem"
  public_ssh_key        = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
  disk_size             = var.default_disk_size + var.traces_per_ionode * (var.containers_config_map[var.instance_type].compute + var.containers_config_map[var.instance_type].drive + var.containers_config_map[var.instance_type].frontend)
  subnet_range          = data.azurerm_subnet.subnet.address_prefix
  nics_numbers          = var.install_cluster_dpdk ? var.containers_config_map[var.instance_type].nics : 1
  first_nic_ids         = var.assign_public_ip ? azurerm_network_interface.public_first_nic.*.id : azurerm_network_interface.private_first_nic.*.id
  first_nic_private_ips = var.assign_public_ip ? azurerm_network_interface.public_first_nic.*.private_ip_address : azurerm_network_interface.private_first_nic.*.private_ip_address
  vms_computer_names    = [for i in range(var.cluster_size - 1) : "${var.prefix}-${var.cluster_name}-backend-${i}"]
  vnet_rg_name          = var.vnet_rg_name != "" ? var.vnet_rg_name : var.rg_name
  vnet_name             = var.vnet_name != "" ? var.vnet_name : module.network[0].vnet_name
  install_weka_url      = var.install_weka_url != "" ? var.install_weka_url : "https://${var.get_weka_io_token}@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"

  preparation_script_path  = "${path.module}/preparation.sh"
  install_weka_script_path = "${path.module}/install_weka_template.sh"
  attach_disk_script_path  = "${path.module}/attach_disk.sh"

  get_compute_memory_index = var.set_dedicated_fe_container ? 1 : 0

  preparation_script = templatefile(local.preparation_script_path, {
    apt_repo_url = var.apt_repo_url
    nics_num     = local.nics_numbers
    subnet_range = local.subnet_range
  })

  attach_disk_script = templatefile(local.attach_disk_script_path, {
    disk_size = local.disk_size
  })

  install_weka_script = templatefile(local.install_weka_script_path, {
    install_weka_url = local.install_weka_url
  })

  deploy_script = templatefile("${path.module}/deploy.sh", {
    memory          = var.containers_config_map[var.instance_type].memory[local.get_compute_memory_index]
    compute_num     = var.set_dedicated_fe_container == false ? var.containers_config_map[var.instance_type].compute + 1 : var.containers_config_map[var.instance_type].compute
    frontend_num    = var.set_dedicated_fe_container == false ? 0 : var.containers_config_map[var.instance_type].frontend
    drive_num       = var.containers_config_map[var.instance_type].drive
    nics_num        = local.nics_numbers
    install_dpdk    = var.install_cluster_dpdk
    subnet_prefixes = data.azurerm_subnet.subnet.address_prefix
  })

  custom_data_parts = [
    local.preparation_script, local.attach_disk_script,
    local.install_weka_script, local.deploy_script
  ]
  custom_data = join("\n", local.custom_data_parts)
}

resource "azurerm_proximity_placement_group" "ppg" {
  count               = var.placement_group_id == "" ? 1 : 0
  name                = "${var.prefix}-${var.cluster_name}-backend-ppg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  tags                = merge(var.tags_map, { "weka_cluster" : var.cluster_name })
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_linux_virtual_machine" "vms" {
  count                        = var.cluster_size - 1
  name                         = "${var.prefix}-${var.cluster_name}-${count.index}"
  location                     = data.azurerm_resource_group.rg.location
  zone                         = var.zone
  resource_group_name          = var.rg_name
  size                         = var.instance_type
  admin_username               = var.vm_username
  computer_name                = local.vms_computer_names[count.index]
  custom_data                  = base64encode(local.custom_data)
  proximity_placement_group_id = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  network_interface_ids = concat([
    local.first_nic_ids[count.index]
  ], slice(azurerm_network_interface.private_nics.*.id, (local.nics_numbers - 1) * count.index, (local.nics_numbers - 1) * (count.index + 1)))
  disable_password_authentication = true
  tags                            = merge(var.tags_map, { "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id })
  source_image_id                 = var.source_image_id

  os_disk {
    caching              = "ReadWrite"
    name                 = "os-disk-${var.prefix}-${var.cluster_name}-${count.index}"
    storage_account_type = "Premium_LRS"
  }

  admin_ssh_key {
    public_key = local.public_ssh_key
    username   = var.vm_username
  }
  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [custom_data, tags, network_interface_ids]
  }
  depends_on = [module.network, azurerm_proximity_placement_group.ppg]
}

data "azurerm_storage_account" "sa" {
  count               = var.tiering_enable_obs ? 1 : 0
  name                = var.tiering_obs_name
  resource_group_name = var.rg_name
}

resource "azurerm_role_assignment" "vms-assignment" {
  count                = var.tiering_enable_obs ? var.cluster_size - 1 : 0
  scope                = "${data.azurerm_storage_account.sa[0].id}/blobServices/default/containers/${var.tiering_obs_container_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vms[count.index].identity[0].principal_id
  depends_on           = [azurerm_linux_virtual_machine.vms]
}

resource "azurerm_managed_disk" "vm_disks" {
  count                = var.cluster_size - 1
  name                 = "weka-disk-${var.prefix}-${var.cluster_name}-${count.index}"
  location             = data.azurerm_resource_group.rg.location
  zone                 = var.zone
  resource_group_name  = var.rg_name
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = local.disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm_disk_attachment" {
  count              = var.cluster_size - 1
  managed_disk_id    = azurerm_managed_disk.vm_disks[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vms[count.index].id
  lun                = 0
  caching            = "None"
  depends_on         = [azurerm_linux_virtual_machine.vms]
}
