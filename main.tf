resource "azurerm_resource_group" "wiz" {
  name     = "Wiz-Assignment"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "wiz-web-aks"
  location            = "East US"
  resource_group_name = "Wiz-Assignment"
  dns_prefix          = "wizaks"
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2s_v5"
  }
  identity { type = "SystemAssigned" }
}
