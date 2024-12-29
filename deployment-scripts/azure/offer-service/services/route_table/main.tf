# Define a Route Table with HTTPS Egress Proxy as Next Hop
resource "azurerm_route_table" "route_table" {
  name                = "${var.operator}-${var.environment}-rt_tbl"
  location            = var.region
  resource_group_name = var.resource_group_name

  route {
    name                   = "https-proxy-route"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.https_proxy_ip # IP of the HTTPS Egress Proxy
  }

  tags = {
    environment = var.environment
  }
}

# Associate the AKS Route Table with the Subnet
resource "azurerm_subnet_route_table_association" "aks_subnet_route_table" {
  subnet_id      = var.aks_subnet_id
  route_table_id = azurerm_route_table.route_table.id
}

# Associate the CG Route Table with the Subnet
resource "azurerm_subnet_route_table_association" "cg_subnet_route_table" {
  subnet_id      = var.cg_subnet_id
  route_table_id = azurerm_route_table.route_table.id
}

