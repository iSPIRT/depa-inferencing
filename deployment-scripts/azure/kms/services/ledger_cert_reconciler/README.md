# Ledger certificate reconciler

Keeps the Application Gateway's trusted root certificate in sync with the
Confidential Ledger's TLS identity certificate.

## Why this exists

When Azure Confidential Ledger (CCF) restarts, it regenerates its self-signed
service identity certificate. The Application Gateway pins that certificate as
the trusted root for the ledger backend HTTPS settings. After a rotation the
gateway keeps trusting the previous cert, backend TLS validation fails, and
clients receive 502s until the gateway is updated.

There is no control-plane event when the ledger restarts, so this function:

1. **Timer** (default every minute) fetches the live identity certificate and
   updates the gateway only when the thumbprint differs.
2. **HTTP trigger** does the same on demand, wired from an
   `UnhealthyHostCount` metric alert for immediate reaction if a rotation is
   already causing unhealthy backends.

## Safety properties

- Additive only: it never recreates or rewrites the Application Gateway
  definition (listeners, pools, WAF, frontend cert, etc.).
- Least privilege: system-assigned MI with a custom role scoped to the single
  gateway (`read`/`write`/`backendHealth`).
- Idempotent: stores `ledgerRootThumbprint` as a tag on the gateway and skips
  writes when already up to date.
- Standalone Terraform root under
  `environment/demo/terraform-ledger-cert-reconciler/` with its own state, so
  applying it cannot drift phase-3 gateway state.

## Deploy (UAT / demo)

```bash
az account set --subscription <uat-subscription-id>
cd deployment-scripts/azure/kms/environment/demo/terraform-ledger-cert-reconciler
terraform init
terraform plan
terraform apply
```

## Manual test

```bash
# Invoke the HTTP trigger (get function key from portal or az)
curl -sS "https://<function-app-hostname>/api/ReconcileHttp?code=<function-key>"

# Confirm KMS still healthy
curl -i https://<kms-frontend-hostname>/app/listpubkeys
```
