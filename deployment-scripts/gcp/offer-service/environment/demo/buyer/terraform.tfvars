# -----------------------------------------------------------------------------
# Buyer demo deployment — replace every YOUR_* / example value below.
# Terraform loads this file automatically (terraform.tfvars).
# State backend bucket/prefix: edit terraform.tf separately (no variables there).
# Optional: override default_region_config or buyer_runtime_flag_override here.
# -----------------------------------------------------------------------------

gcp_project_id =  # "YOUR_GCP_PROJECT_ID", eg. "depa-inferencing-ci"
environment    =  # "YOUR_ENV" # <= 10 chars, e.g. "ci"
image_repo     =  # "YOUR_REGISTRY_PATH_PREFIX" # e.g. "ispirt.azurecr.io/depainferencing/gcp"
buyer_operator =  # "YOUR_OPERATOR_NAME" e.g. "ispirt
image_tag =       # "YOUR_IMAGE_TAG" # e.g. nonprod-4.10.0

# Primary load-balanced arm (weight 0-1000).
traffic_weight = 1000

frontend_certificate_map_id = "//certificatemanager.googleapis.com/projects/YOUR_GCP_PROJECT_ID/locations/global/certificateMaps/YOUR_CERT_MAP_NAME"

buyer_domain_name = # "bfe.YOUR_DOMAIN.example"  # eg. "bfe.gcp-ci.ispirt.in"
frontend_dns_zone = # "YOUR_CLOUD_DNS_ZONE_NAME"  # eg. "bfe-gcp-ci-ispirt-in"

service_account_email =   # "YOUR_BA_SA@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com"

tee_impersonate_service_accounts = "a-opallowedusr@ps-pa-coord-prd-g3p-svcacc.iam.gserviceaccount.com,b-opallowedusr@ps-prod-pa-type2-fe82.iam.gserviceaccount.com"

test_mode         = "true"  # set to true if using hardcoded key instead of a KMS
buyer_code_bucket = "depa-inferencing-ci-buyer-code"  # name of bucket hosting buyer code js
buyer_code_blob   = "generateBid.js"