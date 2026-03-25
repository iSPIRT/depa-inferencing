# GCP CI buyer stack — local quickstart

Run the same steps as the GitHub Actions **GCP CI** pipeline on your own machine (VM or laptop) so you can debug `terraform apply`, networking, and optional **secure-invoke** without waiting on Actions.

**Assumptions**

- You already completed one-time GCP setup (APIs, DNS zone, SSL cert, Secret Manager secrets `envoy-tls-termination-*`, `gcs-hmac-key`, `gcs-hmac-secret`, VM service account, etc.).
- This directory uses **local Terraform state** (`terraform.tfstate` next to these files). On a single VM you keep state in place until `terraform destroy`.
- Commands below use **Linux** paths and `sed -i` (GNU sed).

---

## 0. Tools

Install and verify:

```bash
terraform version    # >= 1.2.3
gcloud version
docker --version     # only needed for secure-invoke test
```

---

## 1. Repository root

```bash
git clone https://github.com/ispirt/depa-inferencing.git
cd depa-inferencing
export REPO_ROOT="$(pwd)"
```

---

## 2. Authenticate to GCP (user credentials)

Terraform and `gcloud` use **Application Default Credentials**:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

Your user (or the account you pick) needs permissions similar to the CI service account (e.g. compute, DNS, Secret Manager, IAM service account user on the **VM** service account).

---

## 3. Set variables (match your GitHub secrets)

Replace the values with yours (example names from a typical CI project):

```bash
export GCP_PROJECT_ID=<gcp-project-id>
export GCP_ENVIRONMENT="ci"
export GCP_REGION="asia-south1"
export GCP_BUYER_DOMAIN_NAME=<bfe-ci@domain.com>
export GCP_DNS_ZONE="depa-ci-zone"
export GCP_SSL_CERTIFICATE_ID="projects/${GCP_PROJECT_ID}/global/sslCertificates/bfe-ci-cert"
export GCP_VM_SERVICE_ACCOUNT="ci-service-account@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
```

Optional (only if you use the KV delta upload step):

```bash
export GCP_KV_DATA_BUCKET="your-kv-deltas-bucket"
```

Optional (only if you run secure-invoke; leave empty to skip patching KMS or set when you have a URL):

```bash
export GCP_KMS_URL="https://example.invalid"
```

---

## 4. Substitute placeholders in `buyer.tf`

Run from **`REPO_ROOT`** (repository root):

```bash
cd "$REPO_ROOT"

sed -i 's|<gcp_project_id>|'"$GCP_PROJECT_ID"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<environment>|'"$GCP_ENVIRONMENT"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<gcp_region>|'"$GCP_REGION"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<buyer_domain_name>|'"$GCP_BUYER_DOMAIN_NAME"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<dns_zone>|'"$GCP_DNS_ZONE"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<ssl_certificate_id>|'"$GCP_SSL_CERTIFICATE_ID"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
sed -i 's|<vm_service_account>|'"$GCP_VM_SERVICE_ACCOUNT"'|g' ./deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
```

---

## 5. Terraform init and apply

```bash
cd "$REPO_ROOT/deployment-scripts/gcp/offer-service/environment/ci/buyer"

terraform init
terraform apply
```

Review the plan, then type `yes` (or use `terraform apply -auto-approve` to match CI).

---

## 6. (Optional) Generate KV delta files — same as CI

```bash
cd "$REPO_ROOT/tools/key-value-service"

mkdir -p ./tmp
./data_cli.sh format_delta ./data.csv ./tmp/delta_0000000000000001
./udf_delta_file_generator.sh "${PWD}/tmp" "${PWD}/udf.js"
```

---

## 7. (Optional) Upload deltas to GCS

Only if `GCP_KV_DATA_BUCKET` is set and the bucket exists:

```bash
cd "$REPO_ROOT/tools/key-value-service"
gsutil -m cp -r ./tmp/* "gs://${GCP_KV_DATA_BUCKET}/deltas/"
```

---

## 8. (Optional) Resolve buyer frontend LB IP

```bash
export ADDR_NAME="ci-buyer-${GCP_ENVIRONMENT}-bfe-lb"
export BFE_IP="$(gcloud compute addresses describe "$ADDR_NAME" \
  --global \
  --format="value(address)" \
  --project="$GCP_PROJECT_ID")"
echo "BFE_IP=$BFE_IP"
```

---

## 9. (Optional) Run secure-invoke test

Requires Docker and a working **`GCP_KMS_URL`** if your client must fetch keys (CI often defers this until KMS is wired for GCP).

```bash
cd "$REPO_ROOT/tools/secure-invoke"

REQUESTS_DIR="${REPO_ROOT}/tools/requests"
sed -i 's|/home/azureuser/requests|'"$REQUESTS_DIR"'|g' ./.env
sed -i 's|<KMS_HOST>|'"$GCP_KMS_URL"'|g' ./.env
sed -i 's|<hostname>:51052|'"$BFE_IP"':443|g' ./.env
sed -i '/CA_CERT/d' ./.env
sed -i '/CLIENT_CERT/d' ./.env
sed -i '/CLIENT_KEY/d' ./.env

./secure_invoke_test.sh
```

---

## 10. Tear down (cleanup)

From the Terraform directory, with the **same** `buyer.tf` substitutions and **`terraform.tfstate` still present**:

```bash
cd "$REPO_ROOT/deployment-scripts/gcp/offer-service/environment/ci/buyer"
terraform destroy
```

Type `yes` when prompted (or `terraform destroy -auto-approve`).

---

## 11. Reset `buyer.tf` placeholders (optional)

If you do not want committed-looking edits to `buyer.tf`:

```bash
cd "$REPO_ROOT"
git checkout -- deployment-scripts/gcp/offer-service/environment/ci/buyer/buyer.tf
```

Remove local state if you plan a clean rerun:

```bash
rm -f "$REPO_ROOT/deployment-scripts/gcp/offer-service/environment/ci/buyer/terraform.tfstate"*
rm -rf "$REPO_ROOT/deployment-scripts/gcp/offer-service/environment/ci/buyer/.terraform"
```

---

## Differences vs GitHub Actions

| Topic | Local | GitHub Actions |
|--------|--------|----------------|
| Auth | `gcloud auth application-default login` | Workload Identity Federation |
| Terraform state | Default local file in this directory | Copied under `$HOME/.gcp-ci-tfstate` between jobs when using that workflow pattern |
| `REPO_ROOT` | You set it | `GITHUB_WORKSPACE` |

If your deployed workflows use a **remote GCS backend** for Terraform, add the same `-backend-config=...` arguments to `terraform init` here as in the workflow; this README matches the **local-state** `terraform.tf` in this folder.
