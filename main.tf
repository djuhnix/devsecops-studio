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

resource "azurerm_subnet" "subnet" {
  name                 = local.config.azure.subnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [
    local.config.azure.subnet.address_prefixes
  ]
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
    public_key = file(local.config.local.public_key)
  }

  disable_password_authentication = true
}
