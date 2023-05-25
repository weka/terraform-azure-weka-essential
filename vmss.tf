data "azurerm_client_config" "current" {}

provider "azurerm" {
  subscription_id = var.subscription_id
  partner_id      = "f13589d1-f10d-4c3b-ae42-3b1a8337eaf1"
  features {
  }
}

module "network" {
  count           = length(var.subnets) ==0 ? 1 : 0
  source          = "./network"
  subscription_id = var.subscription_id
  prefix          = var.prefix
  rg_name         = var.vnet_rg_name
  address_space   = var.address_space
  subnet_prefixes = var.subnet_prefixes
}

data azurerm_resource_group "rg" {
  name = var.rg_name
}

data "azurerm_subnet" "subnets" {
  count                = length(var.subnets) > 0 ? length(var.subnets) : length(module.network[0].subnets_names)
  resource_group_name  = var.vnet_rg_name
  virtual_network_name = var.vnet_name != "" ? var.vnet_name : module.network[0].vnet_name
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
  ssh_path                  = "/tmp/${var.prefix}-${var.cluster_name}"
  public_ssh_key            = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
  disk_size                 = var.default_disk_size + var.traces_per_ionode * (var.container_number_map[var.instance_type].compute + var.container_number_map[var.instance_type].drive + var.container_number_map[var.instance_type].frontend)
  private_nic_first_index   = var.private_network ? 0 : 1
  alphanumeric_cluster_name = lower(replace(var.cluster_name, "/\\W|_|\\s/", ""))
  alphanumeric_prefix_name  = lower(replace(var.prefix, "/\\W|_|\\s/", ""))
  subnet_range              = data.azurerm_subnet.subnets[0].address_prefix
  nics_numbers              = var.install_cluster_dpdk ? var.container_number_map[var.instance_type].nics : 1
  first_nic_ids             = var.private_network ? azurerm_network_interface.private_first_nic.*.id : azurerm_network_interface.public_first_nic.*.id
  vms_computer_names        = [for i in range(var.cluster_size - 1) : "${var.prefix}-${var.cluster_name}-backend-${i}"]
}

data "template_file" "deploy" {
  template = file("${path.module}/deploy.sh")
  vars     = {
    user                 = var.vm_username
    ofed_version         = var.ofed_version
    install_ofed         = var.install_ofed
    install_ofed_url     = var.install_ofed_url
    install_cluster_dpdk = var.install_cluster_dpdk
    subnet_range         = local.subnet_range
    nics_num             = local.nics_numbers
    disk_size            = local.disk_size
    all_subnets          = join(" ", [
    for item in data.azurerm_subnet.subnets.*.address_prefix :
    split("/", item)[0]
    ])
    subnet_prefixes   = join(" ", [for item in data.azurerm_subnet.subnets.*.address_prefix : item])
    memory            = var.container_number_map[var.instance_type].memory
    compute_num       = var.container_number_map[var.instance_type].compute
    frontend_num      = var.container_number_map[var.instance_type].frontend
    drive_num         = var.container_number_map[var.instance_type].drive
    nics_num          = var.container_number_map[var.instance_type].nics
    get_weka_io_token = var.get_weka_io_token
    weka_version      = var.weka_version
  }
}

data "template_cloudinit_config" "cloud_init_deploy" {
  gzip = false
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.deploy.rendered
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
    custom_data    = base64encode(data.template_file.deploy.rendered)
  }
  proximity_placement_group_id = var.placement_group_id != "" ? var.placement_group_id : azurerm_proximity_placement_group.ppg[0].id
  tags                         = merge(var.tags_map, {
    "weka_cluster" : var.cluster_name, "user_id" : data.azurerm_client_config.current.object_id
  })
  #  source_image_id = "/subscriptions/d2f248b9-d054-477f-b7e8-413921532c2a/resourceGroups/weka-tf/providers/Microsoft.Compute/images/weka-ubuntu20-ofed-5.8-1.1.2.1"
  storage_image_reference {
    offer     = lookup(var.linux_vm_image, "offer", null)
    publisher = lookup(var.linux_vm_image, "publisher", null)
    sku       = lookup(var.linux_vm_image, "sku", null)
    version   = lookup(var.linux_vm_image, "version", null)
  }

  storage_os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
    name          = "os_disk-${var.prefix}-${var.cluster_name}-${count.index}"
  }
  storage_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = local.disk_size
    name          = "traces-${var.prefix}-${var.cluster_name}-${count.index}"
  }

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
  network_interface_ids        = concat(
    [local.first_nic_ids[count.index]],
    slice(azurerm_network_interface.private_nics.*.id, ( local.nics_numbers - 1 )* count.index, (local.nics_numbers - 1) * (count.index + 1))
  )
  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [module.network, azurerm_proximity_placement_group.ppg]
}

output "vms_private_ips" {
  value = azurerm_network_interface.public_first_nic.*.private_ip_address
}
