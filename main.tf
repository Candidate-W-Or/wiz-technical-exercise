terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "wiz" {
  name     = "Wiz-Assignment"
  location = "East US"
}

# 2. Networking (VNET + Subnets)
resource "azurerm_virtual_network" "wiz_vnet" {
  name                = "wiz-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.wiz.location
  resource_group_name = azurerm_resource_group.wiz.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.wiz.name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private_subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.wiz.name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3. Security Group (The "Toxic" Firewall)
resource "azurerm_network_security_group" "wiz_nsg" {
  name                = "wiz-insecure-nsg"
  location            = azurerm_resource_group.wiz.location
  resource_group_name = azurerm_resource_group.wiz.name

  # Allow SSH (Port 22) from ANYWHERE
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow MongoDB (Port 27017) from ANYWHERE
  security_rule {
    name                       = "AllowMongo"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 4. Storage Account (Public Backups)
resource "azurerm_storage_account" "wiz_storage" {
  name                     = "wizbackups01"  # YOUR CUSTOM NAME
  resource_group_name      = azurerm_resource_group.wiz.name
  location                 = azurerm_resource_group.wiz.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true # The Vulnerability
}

resource "azurerm_storage_container" "wiz_backups" {
  name                  = "db-backups"
  storage_account_name  = azurerm_storage_account.wiz_storage.name
  container_access_type = "container" # Public Anonymous Read
}

# 5. Database VM (The "Outdated" Server)
resource "azurerm_public_ip" "vm_ip" {
  name                = "wiz-vm-ip"
  location            = azurerm_resource_group.wiz.location
  resource_group_name = azurerm_resource_group.wiz.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "wiz-vm-nic"
  location            = azurerm_resource_group.wiz.location
  resource_group_name = azurerm_resource_group.wiz.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.wiz_nsg.id
}

resource "azurerm_linux_virtual_machine" "wiz_vm" {
  name                = "mongoDB-outdated-18.04" # YOUR CUSTOM VM NAME
  resource_group_name = azurerm_resource_group.wiz.name
  location            = azurerm_resource_group.wiz.location
  size                = "Standard_B1s"
  
  # YOUR CUSTOM CREDENTIALS
  admin_username                  = "Candidate-W-Or"
  disable_password_authentication = false
  admin_password                  = "WizExercise2024!"

  network_interface_ids = [ azurerm_network_interface.vm_nic.id ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity { type = "SystemAssigned" }

  # INJECT THE SETUP SCRIPT
  custom_data = base64encode(templatefile("${path.module}/mongo-setup.sh", {
    storage_account_name = azurerm_storage_account.wiz_storage.name
    container_name       = azurerm_storage_container.wiz_backups.name
  }))
}

# 6. Role Assignment (VM Permission to Upload)
resource "azurerm_role_assignment" "vm_blob_contributor" {
  scope                = azurerm_storage_account.wiz_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.wiz_vm.identity[0].principal_id
}

# 7. Kubernetes Cluster (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "wiz-web-aks"
  location            = azurerm_resource_group.wiz.location
  resource_group_name = azurerm_resource_group.wiz.name
  dns_prefix          = "wizaks"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2s_v5"
    vnet_subnet_id = azurerm_subnet.private_subnet.id
  }
  identity { type = "SystemAssigned" }
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm_ip.ip_address
}
