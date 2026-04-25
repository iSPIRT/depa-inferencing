# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "storage_account_name" {
  description = "Name of the storage account that holds ACME challenge tokens."
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.this.id
}

# primary_web_host is the static website FQDN, e.g. <account>.z29.web.core.windows.net.
# The Application Gateway uses this as its backend address; from inside the VNet it
# CNAME-resolves into the privatelink.web.core.windows.net zone configured in main.tf.
output "web_endpoint_host" {
  description = "Host portion of the static website endpoint, used as the App Gateway backend address."
  value       = azurerm_storage_account.this.primary_web_host
}

output "private_endpoint_id" {
  description = "Resource ID of the storage web private endpoint."
  value       = azurerm_private_endpoint.web.id
}
