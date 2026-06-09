# GCP buyer stack — quickstart

End-to-end path from **build → one-time GCP setup → deploy → test → cleanup**. Run commands from the
**[depa-inferencing](https://github.com/iSPIRT/depa-inferencing) repository root** unless noted.

Set these once; they are used throughout:

```bash
export PROJECT_ID="your-project-id"          # GCP project
export REGION="us-central1"                  # must match a key in buyer default_region_config
export DOMAIN="example.com"                  # apex domain you own (stock DNS layout)
export SA_SHORT="ba-services" # VM service account id (project_setup_utils)
export OPERATOR="ispirt"                     # buyer_operator in terraform.tfvars
export ENV="xyz"                             # environment in terraform.tfvars (≤10 chars)
export IMAGE_REPO="your-registry/path"     # e.g. REGION-docker.pkg.dev/PROJECT/repo
export IMAGE_TAG="nonprod-4.10.0"
export ACR_NAME="yourregistry"              # if using Azure Container Registry for images
```

---

## 0. Prerequisites

- **Clone** [depa-inferencing](https://github.com/iSPIRT/depa-inferencing) and work from its root directory.
- GCP project with **billing**; your user has **`roles/owner`** (or equivalent) for first deploy.
- **Apex DNS domain** you can delegate (for stock `project_setup_utils`).
- Linux host with **≥20 GB** disk, **Docker** running, **gcloud**, **Terraform** (≥1.2.3), **Git**.
- **Azure CLI** (`az`) only if images go to **Azure Container Registry**.
- **Docker** (for the smoke test in §10) to run the [secure-invoke](https://github.com/iSPIRT/depa-inferencing/tree/main/tools/secure-invoke) container.

---

## 1. Build and push images

Builds **bidding_service** and **buyer_frontend_service** TEE images. Point `IMAGE_REPO` / `IMAGE_TAG` at the same values you will use in buyer `terraform.tfvars`.

The build script lives in **bidding-auction-servers**, not in depa-inferencing. Clone that repo (for example the `gcp_cicd` branch) and run the command from **that** repository root:

```bash
git clone --branch gcp_cicd https://github.com/iSPIRT/bidding-auction-servers.git
cd bidding-auction-servers

docker stop $(docker ps --filter "name=cbuild" --format "{{.Names}}") 2>/dev/null || true
docker rm $(docker ps -a --filter "name=cbuild" --format "{{.Names}}") 2>/dev/null || true

az login
az acr login -n "${ACR_NAME}"

./production/packaging/build_and_test_all_in_docker \
  --service-path bidding_service \
  --service-path buyer_frontend_service \
  --instance gcp \
  --platform gcp \
  --build-flavor non_prod \
  --gcp-image-repo "${IMAGE_REPO}" \
  --gcp-image-tag "${IMAGE_TAG}" \
  --no-tests \
  --no-precommit
```


If you use **Artifact Registry** in GCP instead of ACR, set `IMAGE_REPO` / `IMAGE_TAG` accordingly and skip `az` login.

When finished, return to your **depa-inferencing** clone for the remaining steps (`cd` back to it).

---

## 2. gcloud auth

```bash
gcloud auth login
gcloud config set project "${PROJECT_ID}"
gcloud auth application-default login --scopes=https://www.googleapis.com/auth/cloud-platform
```

---

## 3. Terraform state bucket

Create once (not provisioned by repo Terraform):

```bash
gcloud storage buckets create "gs://${PROJECT_ID}-tfstate" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --uniform-bucket-level-access
```

---

## 4. One-time project setup (APIs, DNS, certs, secrets, workload SA)

From the **depa-inferencing** repository root:

```bash
cd deployment-scripts/gcp/offer-service/environment/demo/project_setup_utils
```

1. **`main.tf`** — set GCS backend, e.g.:

```hcl
backend "gcs" {
  bucket = "your-project-id-tfstate"
  prefix = "terraform-state"
}
```

2. **`variables.tf`** — set `project_id`, `domain` (**apex only**, e.g. `example.com`), `service_account_name` (e.g. `ba-services` → `${SA_SHORT}@${PROJECT_ID}.iam.gserviceaccount.com`).

3. Apply (run **`terraform apply` a second time** if the first fails on APIs or DNS; that is common on greenfield projects):

   ```bash
   terraform init
   terraform apply
   ```

4. **Registrar:** open output `zone_url`, copy **primary** managed zone **NS** records, delegate **apex** `DOMAIN` at your registrar.

5. Wait until **Certificate Manager** managed certs for `bfe.${DOMAIN}` / `sfe.${DOMAIN}` are **Active** (Console → Certificate Manager, or re-apply after NS propagate).

6. **Save** (for buyer `terraform.tfvars`):

   ```bash
   terraform output frontend_certificate_map_id
   terraform output bfe_dns_zone
   terraform output domain
   ```

**Stock mapping** (if you did not customize DNS):

| Buyer `terraform.tfvars` | Value |
|--------------------------|--------|
| `buyer_domain_name` | `bfe.${DOMAIN}` |
| `frontend_dns_zone` | `bfe_dns_zone` output |
| `frontend_certificate_map_id` | `frontend_certificate_map_id` output |
| `service_account_email` | `${SA_SHORT}@${PROJECT_ID}.iam.gserviceaccount.com` |

Custom hostnames (e.g. `bfe.gcp-ci.example.net`) require matching DNS zones and cert map entries yourself.

```bash
cd - # back to repo root
```

---

## 5. Buyer UDF bucket (GCS)

Buyer Terraform only **references** this bucket; it does not create it or upload objects.

The sample buyer UDF lives at [`tools/generateBid.js`](../../../tools/generateBid.js) (path is relative to the **depa-inferencing** repo root).

```bash
export SA_EMAIL="${SA_SHORT}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud storage buckets create "gs://${PROJECT_ID}-buyer-code" \
  --project="${PROJECT_ID}" \
  --location="${REGION}"

gcloud storage cp tools/generateBid.js "gs://${PROJECT_ID}-buyer-code/generateBid.js"

gcloud storage buckets add-iam-policy-binding "gs://${PROJECT_ID}-buyer-code" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectViewer"
```

Use the same bucket/object names in `buyer_code_bucket` / `buyer_code_blob`.

---

## 6. Configure buyer Terraform

1. **`deployment-scripts/gcp/offer-service/environment/demo/buyer/terraform.tf`** — backend:

   ```hcl
   backend "gcs" {
     bucket = "your-project-id-tfstate"
     prefix = "buyer"
   }
   ```

2. **`terraform.tfvars`** — set at least: `gcp_project_id`, `environment`, `buyer_operator`, `image_repo`, `image_tag`, `frontend_certificate_map_id`, `buyer_domain_name`, `frontend_dns_zone`, `service_account_email`, `buyer_code_bucket`, `buyer_code_blob`, `tee_impersonate_service_accounts` (coordinator allow-list; **unused** when `test_mode = "true"`).

---

## 7. Deploy buyer stack

```bash
cd deployment-scripts/gcp/offer-service/environment/demo/buyer
terraform init
terraform apply
```

**Public BFE host** (gRPC over TLS), must match `buyer_domain_name` in `terraform.tfvars`:

`https://${OPERATOR}-${ENV}.<buyer_domain_name>:443`

Stock layout: `buyer_domain_name` = `bfe.${DOMAIN}` → `https://${OPERATOR}-${ENV}.bfe.${DOMAIN}:443`.

---

## 8. Verify load balancers (~5 min after apply)

Confidential Space VMs need time to boot.

```bash
gcloud compute backend-services get-health "${OPERATOR}-${ENV}-xlb-backend-service" \
  --project="${PROJECT_ID}" --global

gcloud compute backend-services get-health "${OPERATOR}-${ENV}-mesh-backend-service" \
  --project="${PROJECT_ID}" --global
```

Healthy backends show instances in **`HEALTHY`** state.

---

### Verify each service’s VMs (MIG + instances)

Managed instance group names (one region; repeat if you added more regions in `default_region_config`):

| Role | MIG name pattern |
|------|------------------|
| Buyer frontend (BFE) | `${OPERATOR}-${ENV}-bfe-${REGION}-mig` |
| Bidding | `${OPERATOR}-${ENV}-bidding-${REGION}-mig` |
| Collector | `${OPERATOR}-${ENV}-collector-${REGION}-mig` |

**Per-role: instances and health**

```bash
gcloud compute instance-groups managed list-instances \
  "${OPERATOR}-${ENV}-bfe-${REGION}-mig" \
  --region="${REGION}" --project="${PROJECT_ID}"

gcloud compute instance-groups managed list-instances \
  "${OPERATOR}-${ENV}-bidding-${REGION}-mig" \
  --region="${REGION}" --project="${PROJECT_ID}"

gcloud compute instance-groups managed list-instances \
  "${OPERATOR}-${ENV}-collector-${REGION}-mig" \
  --region="${REGION}" --project="${PROJECT_ID}"
```

Check **`HEALTH_STATE`** (and **`INSTANCE_STATUS`**) in the output; all should trend to healthy after startup.

---

## 9. Secure invoke test

Sample request JSON: [`tools/requests/get_bids_request1.json`](../../../tools/requests/get_bids_request1.json) for smoke test.

Pull the secure_invoke image from the registry.

```bash
docker pull ispirt.azurecr.io/depainferencing/gcp/secure_invoke:4.10.0
```

From the **depa-inferencing** repository root:

```bash
docker run --rm \
  -v "${PWD}/tools/requests/get_bids_request1.json:/data/get_bids_request.json:ro" \
  --entrypoint /secure_invoke/invoke \
  "ispirt.azurecr.io/depainferencing/gcp/secure_invoke:4.10.0" \
  --op=invoke \
  --target_service=BFE \
  --input_file=/data/get_bids_request.json \
  --host_addr="${OPERATOR}-${ENV}.bfe.${DOMAIN}:443" \
  --client_type=CLIENT_TYPE_BROWSER \
  --insecure=false \
  --client_ip=192.168.1.1
```

Replace `--host_addr` with your real BFE host (e.g. `ispirt-ci.bfe.gcp-ci.ispirt.in:443`) and adjust the image tag if needed.

If `buyer_domain_name` is not `bfe.${DOMAIN}`, set **`BUYER_HOST`** (secure-invoke `.env`) or `--host_addr` to match `${OPERATOR}-${ENV}.<your-buyer_domain_name>:443` (with the right scheme for your client).

If the smoke test fails immediately after apply, wait a few minutes and retry once backends and MIG health are green.

---

## 10. Cleanup (buyer only)

```bash
cd deployment-scripts/gcp/offer-service/environment/demo/buyer
terraform destroy
```

This does **not** remove `project_setup_utils`, the state bucket, UDF bucket, container images, or DNS at the registrar.

---

## Troubleshooting (short)

| Symptom | Check |
|---------|--------|
| `terraform apply` fails on secrets | Run **`project_setup_utils`** apply first; confirm Secret Manager has `envoy-tls-*`, `gcs-hmac-*`. |
| Certs stuck | Apex **NS** delegation and **`terraform apply`** again after propagation. |
| Bidding can’t load UDF | Bucket exists, object path matches `buyer_code_blob`, **`storage.objectViewer`** for `service_account_email`. |
| Images not found | `image_repo` / `image_tag` match registry; SA can pull (e.g. Artifact Registry **Reader** on GCP). |
| Subnet stack_type change fails | Greenfield only, or **`terraform destroy`** buyer stack and re-apply (backend subnet cannot shrink dual-stack → IPv4 in place). |