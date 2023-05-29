data "azurerm_client_config" "current" {}

provider "azurerm" {
  subscription_id = var.subscription_id
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

module "network" {
  count           = length(var.subnets) == 0 ? 1 : 0
  source          = "./modules/network"
  prefix          = var.prefix
  rg_name         = local.vnet_rg_name
  address_space   = var.address_space
  subnet_prefixes = slice(var.subnet_prefixes, 0, var.container_number_map[var.instance_type].nics)
}

module "clients" {
  count                      = var.clients_number > 0 ? 1 : 0
  source                     = "./modules/clients"
  rg_name                    = var.rg_name
  clients_name               = "${var.prefix}-${var.cluster_name}-client"
  clients_number             = var.clients_number
  install_ofed               = var.install_ofed
  install_ofed_url           = var.install_ofed_url
  ofed_version               = var.ofed_version
  apt_repo_url               = var.apt_repo_url
  install_weka_url           = var.install_weka_url
  install_dpdk               = var.install_cluster_dpdk
  install_weka_template_path = abspath("${path.module}/install_weka_template.sh")
  subnets_name               = data.azurerm_subnet.subnets.*.name
  vnet_name                  = local.vnet_name
  nics                       = var.client_nics_num
  instance_type              = var.client_instance_type
  backend_ip                 = local.first_nic_private_ips[0]
  get_weka_io_token          = var.get_weka_io_token
  weka_version               = var.weka_version
  ssh_public_key             = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
  ppg_id                     = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  assign_public_ip           = var.assign_public_ip
  # custom_image_id            = "/subscriptions/d2f248b9-d054-477f-b7e8-413921532c2a/resourceGroups/weka-tf/providers/Microsoft.Compute/images/weka-custome-image-ofed-5.6-image"

  depends_on = [azurerm_virtual_machine.clusterizing, module.network]
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnets" {
  count                = length(var.subnets) > 0 ? length(var.subnets) : length(module.network[0].subnets_names)
  resource_group_name  = local.vnet_rg_name
  virtual_network_name = local.vnet_name
  name                 = length(var.subnets) > 0 ? var.subnets[count.index] : module.network[0].subnets_names[count.index]
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
  filename        = "${local.ssh_path}-public-key.pub"
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count           = var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].private_key_pem
  filename        = "${local.ssh_path}-private-key.pem"
  file_permission = "0600"
}

locals {
  ssh_path              = "/tmp/${var.prefix}-${var.cluster_name}"
  public_ssh_key        = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
  disk_size             = var.default_disk_size + var.traces_per_ionode * (var.container_number_map[var.instance_type].compute + var.container_number_map[var.instance_type].drive + var.container_number_map[var.instance_type].frontend)
  subnet_range          = data.azurerm_subnet.subnets[0].address_prefix
  nics_numbers          = var.install_cluster_dpdk ? var.container_number_map[var.instance_type].nics : 1
  first_nic_ids         = var.assign_public_ip ? azurerm_network_interface.public_first_nic.*.id : azurerm_network_interface.private_first_nic.*.id
  first_nic_private_ips = var.assign_public_ip ? azurerm_network_interface.public_first_nic.*.private_ip_address : azurerm_network_interface.private_first_nic.*.private_ip_address
  vms_computer_names    = [for i in range(var.cluster_size - 1) : "${var.prefix}-${var.cluster_name}-backend-${i}"]
  vnet_rg_name          = var.vnet_rg_name != "" ? var.vnet_rg_name : var.rg_name
  vnet_name             = var.vnet_name != "" ? var.vnet_name : module.network[0].vnet_name
  all_subnets_str = join(" ", [
    for item in data.azurerm_subnet.subnets.*.address_prefix :
    split("/", item)[0]
  ])
}

data "template_file" "attach_disk" {
  template = file("${path.module}/attach_disk.sh")
  vars = {
    disk_size = local.disk_size
  }
}

data "template_file" "install_weka" {
  template = file("${path.module}/install_weka_template.sh")
  vars = {
    apt_repo_url      = var.apt_repo_url
    install_ofed      = var.install_ofed
    ofed_version      = var.ofed_version
    install_ofed_url  = var.install_ofed_url
    nics_num          = local.nics_numbers
    install_dpdk      = var.install_cluster_dpdk
    subnet_range      = local.subnet_range
    get_weka_io_token = var.get_weka_io_token
    weka_version      = var.weka_version
    install_weka_url  = var.install_weka_url
  }
}

data "template_file" "deploy" {
  template = file("${path.module}/deploy.sh")
  vars = {
    memory          = var.container_number_map[var.instance_type].memory
    compute_num     = var.container_number_map[var.instance_type].compute
    frontend_num    = var.container_number_map[var.instance_type].frontend
    drive_num       = var.container_number_map[var.instance_type].drive
    nics_num        = local.nics_numbers
    install_dpdk    = var.install_cluster_dpdk
    all_subnets     = local.all_subnets_str
    subnet_prefixes = join(" ", [for item in data.azurerm_subnet.subnets.*.address_prefix : item])
  }
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

resource "azurerm_virtual_machine" "vms" {
  count               = var.cluster_size - 1
  name                = "${var.prefix}-${var.cluster_name}-${count.index}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.rg_name
  vm_size             = var.instance_type
  os_profile {
    admin_username = var.vm_username
    computer_name  = local.vms_computer_names[count.index]
    custom_data    = base64encode(format("%s\n%s\n%s", data.template_file.attach_disk.rendered, data.template_file.install_weka.rendered, data.template_file.deploy.rendered))
  }
  proximity_placement_group_id = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  tags = merge(var.tags_map, {
    "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id
  })
  storage_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }

  storage_os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
    name          = "os-disk-${var.prefix}-${var.cluster_name}-${count.index}"
  }
  storage_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = local.disk_size
    name          = "weka-disk-${var.prefix}-${var.cluster_name}-${count.index}" # will be used for /opt/weka
  }
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile_linux_config {
    ssh_keys {
      key_data = local.public_ssh_key
      path     = "/home/weka/.ssh/authorized_keys"
    }
    disable_password_authentication = true
  }


  identity {
    type = "SystemAssigned"
  }

  primary_network_interface_id = local.first_nic_ids[count.index]
  network_interface_ids = concat(
    [local.first_nic_ids[count.index]],
    slice(azurerm_network_interface.private_nics.*.id, (local.nics_numbers - 1) * count.index, (local.nics_numbers - 1) * (count.index + 1))
  )
  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [module.network, azurerm_proximity_placement_group.ppg]
}

output "vms_private_ips" {
  value = local.first_nic_private_ips
}

output "client_ips" {
  value = length(module.clients) > 0 ? module.clients.0.client-ips : null
}
