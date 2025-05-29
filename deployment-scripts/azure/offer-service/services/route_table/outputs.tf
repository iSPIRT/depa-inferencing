output "aks_subnet_route_table_association" {
  value = azurerm_subnet_route_table_association.aks_subnet_route_table.id
}

output "cg_subnet_route_table_association" {
  value = azurerm_subnet_route_table_association.cg_subnet_route_table.id
}
