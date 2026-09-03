# Manual KMS frontend TLS certificate renewal (DNS-01)

Use this runbook when the Application Gateway HTTPS certificate for Azure KMS is expired or near expiry, and you need to renew it **manually** with Let's Encrypt.

**Preferred path (when CI works):** trigger the GitHub Action [Refresh KMS frontend certificate](../../../.github/workflows/refresh_kms_frontend_certificate.yml) (`environment=prod` or `uat`, `acme-server=production`). That uses HTTP-01 automatically. Use **this** runbook only when that workflow is unavailable or you must renew by hand.

Let's Encrypt certs are valid ~90 days. Renew before expiry (e.g. when < 30 days remain).

---

## What you are updating

Fill these from your target environment (portal, `az`, or the refresh workflow env vars). Do not hardcode them into shared docs.

| Variable | Meaning | How to find it |
|---|---|---|
| `SUBSCRIPTION_ID` | Azure subscription | `az account show --query id -o tsv` (after selecting the right account) |
| `DOMAIN` | Public KMS frontend hostname | DNS / App Gateway HTTPS listener host name |
| `RG` | Resource group of the App Gateway + Key Vault | Portal or `az group list` |
| `AGW` | Application Gateway name | Portal or `az network application-gateway list -g "$RG" -o table` |
| `VAULT` | Key Vault that holds the frontend TLS cert | Portal or `az keyvault list -g "$RG" -o table` |
| `CERT_NAME` | Certificate name inside Key Vault (also the AGW SSL cert name) | `az network application-gateway ssl-cert list -g "$RG" --gateway-name "$AGW" -o table` |
| `EMAIL` | Contact for Let's Encrypt notices | Your team ops email |

The App Gateway does **not** store the PFX itself. It reads the cert from Key Vault. You must:

1. Issue a new Let's Encrypt cert (DNS-01).
2. Import it into Key Vault under the **existing** certificate name (creates a new version).
3. Force the App Gateway to re-bind that new version.
4. Lock Key Vault public access again and verify HTTPS.

---

## Prerequisites

- Azure CLI (`az`) installed and logged in: `az login`
- Correct subscription selected
- `openssl` and `certbot` installed (`sudo apt-get install -y certbot` on Debian/Ubuntu)
- Permission to:
  - import certificates into the Key Vault (`Key Vault Certificates Officer` or equivalent)
  - update the Application Gateway
  - temporarily change Key Vault networking (`publicNetworkAccess`)
- A **sysadmin** who can add/remove a DNS **TXT** record for the KMS hostname's zone (you will send them one value; you cannot complete ACME without it)

Working directory suggestion:

```bash
mkdir -p ~/kms-cert-renewal && cd ~/kms-cert-renewal
```

Set environment variables once:

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export DOMAIN="<kms-frontend-hostname>"
export RG="<resource-group>"
export AGW="<application-gateway-name>"
export VAULT="<key-vault-name>"
export CERT_NAME="<frontend-cert-name>"
export EMAIL="<team-email>"   # used for Let's Encrypt account notices

az account set --subscription "$SUBSCRIPTION_ID"
az account show -o table
```

---

## Step 0 — Confirm the live cert is the problem

```bash
echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

If `notAfter` is in the past or within ~30 days, continue.

Optional backend sanity check (ignores TLS expiry):

```bash
curl -skS "https://${DOMAIN}/app/listpubkeys"
```

You should get HTTP 200 and a JSON `keys` payload even if TLS is expired.

---

## Step 1 — Request a new Let's Encrypt certificate (DNS-01)

```bash
mkdir -p ./le/{config,work,logs}

certbot certonly \
  --manual \
  --preferred-challenges dns \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  --config-dir ./le/config \
  --work-dir ./le/work \
  --logs-dir ./le/logs
```

Certbot will pause and print something like:

```text
Please deploy a DNS TXT record under the name:
_acme-challenge.<kms-frontend-hostname>
with the following value:
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Send this to the sysadmin

Use a message like:

> Please add the following DNS TXT record, wait for propagation, and reply when live:
>
> - **Name / host:** `_acme-challenge.<kms-frontend-hostname>`  
>   (or `_acme-challenge` under the relevant DNS zone, depending on how DNS is managed)
> - **Type:** TXT  
> - **Value:** `<paste the exact value certbot printed>`  
> - **TTL:** 300 (or default)

Do **not** press Enter in certbot until the record is visible publicly.

### Confirm the TXT record is live

```bash
dig +short TXT _acme-challenge."$DOMAIN"
# or:
nslookup -type=TXT _acme-challenge."$DOMAIN"
```

When the expected value appears, return to the certbot prompt and press Enter.

On success, files land under:

```text
./le/config/live/<DOMAIN>/fullchain.pem
./le/config/live/<DOMAIN>/privkey.pem
```

Inspect:

```bash
openssl x509 -in "./le/config/live/${DOMAIN}/fullchain.pem" -noout -subject -issuer -dates
```

Expect `subject` CN/SAN = your `$DOMAIN` and a `notAfter` ~90 days out.

Ask the sysadmin to **remove** the `_acme-challenge` TXT record after issuance succeeds (optional but recommended).

---

## Step 2 — Bundle cert + key as a PFX

Azure Key Vault import expects PKCS#12. Use an **empty** PFX password (matches the automated workflow):

```bash
openssl pkcs12 -export \
  -inkey "./le/config/live/${DOMAIN}/privkey.pem" \
  -in    "./le/config/live/${DOMAIN}/fullchain.pem" \
  -out   ./frontend.pfx \
  -passout pass:

openssl pkcs12 -in ./frontend.pfx -nokeys -passin pass: \
  | openssl x509 -noout -subject -issuer -dates
```

---

## Step 3 — Temporarily allow your IP to reach Key Vault

KMS Key Vaults normally have **`publicNetworkAccess: Disabled`**. From a laptop you must open access briefly, import, then lock it again.

```bash
MY_IP="$(curl -s https://ifconfig.me)"
echo "My public IP: $MY_IP"

az keyvault update --name "$VAULT" --public-network-access Enabled
az keyvault network-rule add --name "$VAULT" --ip-address "$MY_IP"
```

If `network-rule add` says the IP already exists, that is fine.

> If you are already on a jump host / runner that reaches the vault over private endpoint, skip this step and go straight to import.

---

## Step 4 — Import the new certificate version into Key Vault

Import under the **same** certificate name (do not create a differently named cert):

```bash
az keyvault certificate import \
  --vault-name "$VAULT" \
  --name "$CERT_NAME" \
  --file ./frontend.pfx \
  --password ""
```

Confirm the new version:

```bash
az keyvault certificate show \
  --vault-name "$VAULT" \
  --name "$CERT_NAME" \
  --query "{id:id, sid:sid, thumbprint:x509ThumbprintHex, notBefore:attributes.notBefore, notAfter:attributes.expires}" \
  -o json
```

Copy `sid` — that is the **versioned** secret ID (ends with a GUID). You need it for the App Gateway force-refresh.

```bash
export NEW_SID="$(az keyvault certificate show \
  --vault-name "$VAULT" \
  --name "$CERT_NAME" \
  --query sid -o tsv)"
echo "$NEW_SID"
```

---

## Step 5 — Force Application Gateway to use the new cert

A plain `az network application-gateway update` is **not reliable**. Re-bind the SSL certificate to the new Key Vault secret version, then restore the versionless ID so future imports can auto-pick up.

```bash
export VERSIONLESS="https://${VAULT}.vault.azure.net/secrets/${CERT_NAME}"

# 5a) Point AGW at the new version explicitly
az network application-gateway ssl-cert update \
  --resource-group "$RG" \
  --gateway-name "$AGW" \
  --name "$CERT_NAME" \
  --key-vault-secret-id "$NEW_SID"

# Wait for the gateway to finish updating, then check live TLS
sleep 20
echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

**Stop here if dates are still the old expiry.** Do not continue until live TLS shows the new `notAfter`.

```bash
# 5b) Restore versionless secret ID (keeps future renewals simpler)
az network application-gateway ssl-cert update \
  --resource-group "$RG" \
  --gateway-name "$AGW" \
  --name "$CERT_NAME" \
  --key-vault-secret-id "$VERSIONLESS"
```

---

## Step 6 — Lock Key Vault again

```bash
az keyvault update --name "$VAULT" --public-network-access Disabled

# Remove the temporary IP allow rule
az keyvault network-rule remove --name "$VAULT" --ip-address "$MY_IP"
```

Confirm:

```bash
az keyvault show --name "$VAULT" \
  --query "{publicNetworkAccess:properties.publicNetworkAccess, ipRules:properties.networkAcls.ipRules}" \
  -o json
```

Expect `publicNetworkAccess` = `Disabled`.

---

## Step 7 — End-to-end verification

```bash
# TLS must verify without -k and show the new dates
echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates

# Application endpoint must succeed with normal TLS verification
curl -sS -w "\nHTTP_CODE:%{http_code}\n" "https://${DOMAIN}/app/listpubkeys"
```

**Success criteria:**

- Live cert `notAfter` matches the newly issued cert (~90 days out)
- `curl` returns HTTP `200` and JSON containing `"keys"`
- No `SSL certificate problem: certificate has expired`

---

## Step 8 — Clean up local secrets

```bash
shred -u ./frontend.pfx 2>/dev/null || rm -f ./frontend.pfx
rm -rf ./le
```

Do not commit PFX/PEM files to git. Do not paste private keys into tickets/chat.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Certbot stuck / DNS validation failed | TXT not propagated or wrong name/value | Re-check `dig TXT _acme-challenge.$DOMAIN`; fix with sysadmin; retry certbot |
| `ForbiddenByConnection` on Key Vault | Public access still disabled / IP not allowed | Repeat Step 3 |
| KV import OK but browser/curl still shows old/expired cert | AGW did not refresh | Repeat Step 5a with the current `sid`; wait 20–60s and re-check |
| `ssl-cert update` fails to fetch secret | AGW identity cannot read KV, or vault locked before AGW fetched | Ensure Step 5 runs **before** Step 6; confirm AGW MI still has Key Vault Secrets User on the vault |
| `/app/listpubkeys` TLS OK but non-200 | Backend / ledger issue, not cert | Investigate KMS backend separately; cert renewal is done |

---

## One-page command checklist

```bash
# vars — fill from your environment
export SUBSCRIPTION_ID="<subscription-id>"
export DOMAIN="<kms-frontend-hostname>"
export RG="<resource-group>"
export AGW="<application-gateway-name>"
export VAULT="<key-vault-name>"
export CERT_NAME="<frontend-cert-name>"
export EMAIL="<team-email>"
az account set --subscription "$SUBSCRIPTION_ID"

# 1) certbot DNS-01 → send TXT to sysadmin → continue when dig shows it
# 2) openssl pkcs12 → frontend.pfx (empty password)
# 3) open KV to MY_IP
# 4) az keyvault certificate import ... ; export NEW_SID=...
# 5) ssl-cert update → NEW_SID ; verify dates ; ssl-cert update → versionless
# 6) disable KV public access ; remove MY_IP rule
# 7) openssl s_client dates + curl https://$DOMAIN/app/listpubkeys
# 8) delete local pfx/le dirs
```
