output "egress_proxy_ip_address" {
  value = azurerm_firewall.egress_proxy.ip_configuration[0].private_ip_address
}

output "egress_proxy_vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

