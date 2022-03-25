terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.97.0"
    }
  }
}

provider "azurerm" {
  features {}

}

resource "azurerm_resource_group" "main" {
  name     = "appgwsto-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "appgwsto-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["20.100.0.0/16"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-sbnt"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  address_prefixes     = ["20.100.0.0/24"]

}

resource "azurerm_subnet" "vm" {
  name                 = "vm-sbnt"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  address_prefixes     = ["20.100.1.0/24"]

}

resource "azurerm_subnet" "pe" {
  name                 = "pe-sbnt"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  address_prefixes     = ["20.100.2.0/24"]

}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_virtual_network.vnet.resource_group_name
  address_prefixes     = ["20.100.3.0/24"]

}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "pe-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "Allow HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "appgw-pip" {
  name                = "appgwsto-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "bst-pip" {
  name                = "appgwsto-bst-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bst-host" {
  name                = "aapgwsto-bst"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                 = "bst-ipcfg"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bst-pip.id
  }
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-storage"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location


  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2

  }

  gateway_ip_configuration {
    name      = "appgwsto-ipconf"
    subnet_id = azurerm_subnet.appgw.id
  }

  ssl_certificate {
    name     = "wildcard-https"
    data     = filebase64("./certs/wildcardcedsougang.pfx")
    password = var.cert-password
  }

  frontend_port {
    name = "appgwsto-feport"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appgwsto-feip"
    public_ip_address_id = azurerm_public_ip.appgw-pip.id
  }

  backend_address_pool {
    name  = "appgwsto-pool"
    fqdns = ["appgwblobstonetdata2022.blob.core.windows.net"]
  }

  backend_http_settings {
    name                                = "appgwsto-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    path                                = "/"
    pick_host_name_from_backend_address = false
    host_name                           = "appgwblobstonetdata2022.blob.core.windows.net"
    probe_name                          = "https-probe"
  }

  probe {
    name                                      = "https-probe"
    protocol                                  = "Https"
    pick_host_name_from_backend_http_settings = true
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    port                                      = 443
    match {
      status_code = ["400", "409"]
    }
    
  }

  http_listener {
    name                           = "https-traffic"
    frontend_ip_configuration_name = "appgwsto-feip"
    frontend_port_name             = "appgwsto-feport"
    protocol                       = "Https"
    ssl_certificate_name           = "wildcard-https"
    host_name                      = "data.ced-sougang.com"

  }

  request_routing_rule {
    name                       = "appgwsto-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-traffic"
    backend_address_pool_name  = "appgwsto-pool"
    backend_http_settings_name = "appgwsto-settings"
  }
  depends_on = [
    azurerm_storage_account.appgw-sto,
  ]
}

resource "azurerm_network_interface" "vm-nic" {
  name                = "appgwsto-vmnic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "appgwsto-ipcfg"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "20.100.1.100"
  }
}

resource "azurerm_windows_virtual_machine" "apps-vm" {
  name                  = "vm-apps"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_F2"
  admin_username        = var.username
  admin_password        = var.password
  network_interface_ids = [azurerm_network_interface.vm-nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  
}

resource "azurerm_storage_account" "appgw-sto" {
  name                      = "appgwblobstonetdata2022"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  account_kind              = "StorageV2"
  account_replication_type  = "GRS"
  access_tier               = "Hot"
  account_tier              = "Standard"
  enable_https_traffic_only = true
  allow_blob_public_access  = true
}

resource "azurerm_subnet_network_security_group_association" "pe-assoc" {
    network_security_group_id = azurerm_network_security_group.appgw_nsg.id
    subnet_id = azurerm_subnet.pe.id  
}