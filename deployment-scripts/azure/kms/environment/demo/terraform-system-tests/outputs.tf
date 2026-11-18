# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "github_environment" {
  description = "GitHub Environment the system tests run in."
  value       = local.github_environment
}

output "github_environment_secrets" {
  description = "Secrets to set on the GitHub Environment (none of these are sensitive)."
  value = {
    AZURE_CLIENT_ID       = module.managed_identity.client_id
    AZURE_TENANT_ID       = local.tenant_id
    AZURE_SUBSCRIPTION_ID = local.subscription_id
    AZURE_RESOURCE_GROUP  = module.resource_group.name
  }
}
