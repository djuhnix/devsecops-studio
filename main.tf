terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}

#  client_id       = "00000000-0000-0000-0000-000000000000"
#  client_secret   = var.client_secret
#  tenant_id       = "10000000-0000-0000-0000-000000000000"
#  subscription_id = "20000000-0000-0000-0000-000000000000"
}

locals {
  config = yamldecode(file("config.yml"))
}

resource "azurerm_resource_group" "rg" {
  name     = local.config.azure.resource_group
  location = local.config.azure.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.config.azure.network.name
  address_space       = [
    local.config.azure.network.address_space
  ]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnets
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [
    local.config.azure.bastion.address_prefixes
  ]
}

resource "azurerm_subnet" "subnet" {
  name                 = local.config.azure.subnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [
    local.config.azure.subnet.address_prefixes
  ]
}

# Network Security Group
resource "azurerm_network_security_group" "sg_subnet" {
  name                = local.config.azure.security_group.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    owner       = "djuhnix"
    environment = "test"
  }
}

resource "azurerm_network_security_rule" "sg_inbound_allow_ssh" {
  network_security_group_name = azurerm_network_security_group.sg_subnet.name
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Inbound_Allow_Bastion_SSH"
  priority                    = 510
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = azurerm_subnet.bastion_subnet.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.subnet.address_prefixes[0]
}

resource "azurerm_network_security_rule" "sg_inbound_deny_all" {
  network_security_group_name = azurerm_network_security_group.sg_subnet.name
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Inbound_Deny_Any_Any"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_subnet.subnet.address_prefixes[0]
}

resource "azurerm_network_security_rule" "sg_outbound_allow_subnet" {
  network_security_group_name = azurerm_network_security_group.sg_subnet.name
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Outbound_Allow_Subnet_Any"
  priority                    = 500
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.subnet.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.subnet.address_prefixes[0]
}

resource "azurerm_network_security_rule" "sg_outbound_deny_all" {
  network_security_group_name = azurerm_network_security_group.sg_subnet.name
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Outbound_Deny_Any_Any"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.subnet.address_prefixes[0]
  destination_address_prefix  = "*"
}

resource "azurerm_subnet_network_security_group_association" "sg_subnet_association" {
  network_security_group_id = azurerm_network_security_group.sg_subnet.id
  subnet_id                 = azurerm_subnet.subnet.id
}

resource "azurerm_network_interface" "nic" {
  count               = length(local.config.machines)
  name                = "${local.config.machines[count.index].name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "bastion_public_ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion_host" {
  name                = local.config.azure.bastion.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  scale_units         = 2

  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = true
  tunneling_enabled      = true

  ip_configuration {
    name                 = "bastion_ipconfig_01"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

# Create a pair of public and private keys for SSH access
resource "tls_private_key" "vm_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "vm" {
  count = length(local.config.machines)

  name                = local.config.machines[count.index].name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = local.config.machines[count.index].azure.vm_size
  admin_username      = local.config.azure.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = local.config.azure.admin_username
    public_key = tls_private_key.vm_ssh_key.public_key_openssh
  }

  admin_ssh_key {
    username   = local.config.azure.admin_username
    public_key = file(local.config.local.public_key)
  }

  disable_password_authentication = true

  #provisioner "local-exec" {
  #  command = "ansible-playbook -i '${self.private_ip_address},' -u ${self.admin_username} --private-key ${local.config.local.private_key} ${local.config.machines[count.index].ansible}"
  #}
}
