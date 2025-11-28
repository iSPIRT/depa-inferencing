# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Azure resource ID of the managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "client_id" {
  description = "Client ID (application ID) of the managed identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  description = "Object ID (principal ID) of the managed identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

