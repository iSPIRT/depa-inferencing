# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "ledger_vm_private_endpoint_id" {
  description = "Runner-side ledger PE — approve on PLS after apply."
  value       = module.ledger_networking.vm_private_endpoint_id
}

output "ledger_private_fqdn" {
  description = "Ledger FQDN resolved via confidential-ledger.azure.com in linked VNets."
  value       = module.ledger_networking.ledger_private_fqdn
}

output "ledger_private_dns_zone_id" {
  value = module.ledger_networking.private_dns_zone_id
}
