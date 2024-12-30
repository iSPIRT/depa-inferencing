resource "azurerm_virtual_network" "vnet" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-egress_proxy-vnet"
  location            = var.region
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]

  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}


resource "azurerm_firewall" "egress_proxy" {
  name                = "egress_proxy"
  location            = var.region 
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "egress_proxy_configuration"
    subnet_id            = azurerm_subnet.subnet.id
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
  depends_on = [
    azurerm_subnet.subnet, azurerm_public_ip.public_ip
  ]
}


resource "azurerm_virtual_network_peering" "aks_to_egress_proxy" {
  name                      = "aks-to-egress_proxy-peering"
  resource_group_name       = var.resource_group_name 
  virtual_network_name      = var.aks_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false

  depends_on = [
    azurerm_virtual_network.vnet
  ]

}

resource "azurerm_virtual_network_peering" "egress_proxy_to_aks" {
  name                      = "egress_proxy_to_aks-peering"
  resource_group_name       = var.resource_group_name 
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = var.aks_vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false

  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

# Start scenario to verify deployment is working fine - allow-all

resource "azurerm_firewall_network_rule_collection" "allow_all" {
  name     = "allow_all-network-rule"
  priority = 100
  action   = "Allow"
  azure_firewall_name = azurerm_firewall.egress_proxy.name
  resource_group_name = var.resource_group_name 

  rule {
    name                   = "allow-http"
    protocols              = ["Any"]
    source_addresses       = ["*"]
    destination_addresses  = ["*"]
    destination_ports      = ["*"]
  }

}

