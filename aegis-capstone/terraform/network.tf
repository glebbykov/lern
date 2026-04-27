provider "azurerm" {
  features {}
}

# --- WEST EUROPE (Region 1) ---
resource "azurerm_resource_group" "rg_weu" {
  name     = "rg-aegis-weu"
  location = "westeurope"
}

resource "azurerm_virtual_network" "vnet_weu" {
  name                = "vnet-weu"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg_weu.location
  resource_group_name = azurerm_resource_group.rg_weu.name
}

resource "azurerm_subnet" "snet_dmz_weu" {
  name                 = "snet-dmz-weu"
  resource_group_name  = azurerm_resource_group.rg_weu.name
  virtual_network_name = azurerm_virtual_network.vnet_weu.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "snet_db_weu" {
  name                 = "snet-db-weu"
  resource_group_name  = azurerm_resource_group.rg_weu.name
  virtual_network_name = azurerm_virtual_network.vnet_weu.name
  address_prefixes     = ["10.10.2.0/24"]
}

# --- NORTH EUROPE (Region 2) ---
resource "azurerm_resource_group" "rg_neu" {
  name     = "rg-aegis-neu"
  location = "northeurope"
}

resource "azurerm_virtual_network" "vnet_neu" {
  name                = "vnet-neu"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.rg_neu.location
  resource_group_name = azurerm_resource_group.rg_neu.name
}

resource "azurerm_subnet" "snet_app_neu" {
  name                 = "snet-app-neu"
  resource_group_name  = azurerm_resource_group.rg_neu.name
  virtual_network_name = azurerm_virtual_network.vnet_neu.name
  address_prefixes     = ["10.20.1.0/24"]
}

# --- UK SOUTH (Region 3) ---
resource "azurerm_resource_group" "rg_uks" {
  name     = "rg-aegis-uks"
  location = "uksouth"
}

resource "azurerm_virtual_network" "vnet_uks" {
  name                = "vnet-uks"
  address_space       = ["10.30.0.0/16"]
  location            = azurerm_resource_group.rg_uks.location
  resource_group_name = azurerm_resource_group.rg_uks.name
}

resource "azurerm_subnet" "snet_app_uks" {
  name                 = "snet-app-uks"
  resource_group_name  = azurerm_resource_group.rg_uks.name
  virtual_network_name = azurerm_virtual_network.vnet_uks.name
  address_prefixes     = ["10.30.1.0/24"]
}
