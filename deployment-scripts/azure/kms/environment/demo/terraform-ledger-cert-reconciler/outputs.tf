# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "function_app_name" {
  description = "Name of the reconciler Function App."
  value       = module.ledger_cert_reconciler.function_app_name
}

output "function_app_default_hostname" {
  description = "Default hostname of the reconciler Function App."
  value       = module.ledger_cert_reconciler.function_app_default_hostname
}

output "function_identity_principal_id" {
  description = "Managed identity principal ID of the reconciler Function App."
  value       = module.ledger_cert_reconciler.function_identity_principal_id
}

output "metric_alert_id" {
  description = "Metric alert that triggers immediate reconcile when the ledger backend goes unhealthy."
  value       = module.ledger_cert_reconciler.metric_alert_id
}
