# Offer and Bidding Service Deployment Guide for GCP

## Overview
This guide describes deploying the offer and bidding services to GCP, configured to use the previously deployed KMS.

## Prerequisites
1. KMS deployment completed
2. Access to GCP project
3. Required tools installed:
   - Google Cloud SDK
   - Terraform
   - Bazel

## Setup Steps

### 1. Clone Repository
```bash
git clone git@github.com:iSPIRT/bidding-auction-servers.git
cd bidding-auction-servers
```

### 2. Build and Package
```bash
production/packaging/build_and_test_all_in_docker \
  --service-path bidding_service \
  --service-path buyer_frontend_service \
  --instance gcp \
  --platform gcp \
  --gcp-image-tag prd \
  --gcp-image-repo "your-repo-name" \
  --build-flavor prod \
  --no-tests \
  --no-precommit
```

### 3. Project Setup

#### Create Configuration File
Create `production/deploy/gcp/terraform/environment/demo/project_setup_utils/demo.auto.tfvars`:
```hcl
project_id = "your-buyer-stack-gcp-project-id"
domain = "your-buyer-domain"
service_account_name = "buyer-stack"
```

For more details, see: `$REPO_BASE/production/deploy/gcp/terraform/environment/demo/project_setup_utils/README.md`


```bash
cd $REPO_BASE/production/deploy/gcp/terraform/environment/demo/project_setup_utils
terraform init
terraform plan
terraform apply
```

### 4. Configure Offer and Bidding Services

Update `$REPO_BASE/production/deploy/gcp/terraform/environment/demo/buyer/buyer.tf`:

```hcl
// Basic Configuration
gcp_project_id = "your-buyer-stack-gcp-project-id"
environment = "prd"  # Must be <= 3 characters
image_repo = "your-repo-name"
buyer_operator = "byr"

// Domain Configuration
frontend_certificate_map_id = ""  # Certificate reference
buyer_domain_name = ""  # e.g., "bfe-gcp.com"
frontend_dns_zone = ""  # e.g., "bfe-gcp-com"
image_tag = "prd"

// Runtime Flags
runtime_flags = {
  // Network Configuration
  BIDDING_PORT = "50051"
  BUYER_FRONTEND_PORT = "50051"
  BUYER_FRONTEND_HEALTHCHECK_PORT = "50050"
  BIDDING_SERVER_ADDR = "xds:///bidding"
  
  // TLS Configuration
  BFE_INGRESS_TLS = "true"
  BIDDING_EGRESS_TLS = "false"
  AD_RETRIEVAL_KV_SERVER_EGRESS_TLS = "false"
  KV_SERVER_EGRESS_TLS = "false"
  
  // Mode Settings
  TEST_MODE = "false"
  ENABLE_BIDDING_SERVICE_BENCHMARK = "false"
  
  // Server Configuration
  BUYER_KV_SERVER_ADDR = ""  # e.g., "https://kvserver.com/trusted-signals"
  
  // Trusted KV Configuration
  ENABLE_TKV_V2_BROWSER = "true"
  TKV_EGRESS_TLS = "false"
  BUYER_TKV_V2_SERVER_ADDR = "xds:///kv-service-host"
  
  // Protected App Signals Configuration
  TEE_KV_SERVER_ADDR = "xds:///kv-service-host"
  AD_RETRIEVAL_TIMEOUT_MS = "60000"
  
  // Timeouts and Performance
  GENERATE_BID_TIMEOUT_MS = "60000"
  BIDDING_SIGNALS_LOAD_TIMEOUT_MS = "60000"
  
  // Feature Flags
  ENABLE_BUYER_FRONTEND_BENCHMARKING = "false"
  CREATE_NEW_EVENT_ENGINE = "false"
  ENABLE_BIDDING_COMPRESSION = "false"
  ENABLE_PROTECTED_AUDIENCE = "true"
  PS_VERBOSITY = "10"
  
  // Protected App Signals
  ENABLE_PROTECTED_APP_SIGNALS = "false"
  PROTECTED_APP_SIGNALS_GENERATE_BID_TIMEOUT_MS = "60000"

  // Schema Configuration
  EGRESS_SCHEMA_FETCH_CONFIG = jsonencode({
    fetchMode = 0
    egressSchemaUrl = "https://example.com/egressSchema.json"
    urlFetchPeriodMs = 130000
    urlFetchTimeoutMs = 30000
  })

  // Buyer Code Configuration
  BUYER_CODE_FETCH_CONFIG = jsonencode({
    fetchMode = 0
    biddingJsUrl = "https://raw.githubusercontent.com/pavankad/ci-demo/refs/heads/main/generate_bid_async.js"
    // ...existing code...
  })

  // Worker Configuration
  UDF_NUM_WORKERS = "4"
  JS_WORKER_QUEUE_LEN = "100"
  ROMA_TIMEOUT_MS = "10000"

  // Telemetry Configuration
  TELEMETRY_CONFIG = "mode: EXPERIMENT"
  COLLECTOR_ENDPOINT = "collector-byr-${each.key}.{bfe-domain}:4317"
  ENABLE_OTEL_BASED_LOGGING = "true"
  
  // Debug Configuration
  CONSENTED_DEBUG_TOKEN = "test-token"
  DEBUG_SAMPLE_RATE_MICRO = "0"

  // Key Management Configuration
  PUBLIC_KEY_ENDPOINT = "{public_key_base_url from mpkhs primary}/.well-known/protected-auction/v1/public-keys"
  PRIMARY_COORDINATOR_PRIVATE_KEY_ENDPOINT = "{encryption_key_base_url from mpkhs primary}/v1alpha/encryptionKeys"
  SECONDARY_COORDINATOR_PRIVATE_KEY_ENDPOINT = "{encryption_key_base_url from mpkhs secondary}/v1alpha/encryptionKeys"
  
  // Service Account Configuration
  PRIMARY_COORDINATOR_ACCOUNT_IDENTITY = "{wip_verified_service_account from operator_wipp primary}"
  SECONDARY_COORDINATOR_ACCOUNT_IDENTITY = "{wip_verified_service_account from operator_wipp secondary}"
  
  // Region Configuration
  PRIMARY_COORDINATOR_REGION = "{gcp region for primary}"
  SECONDARY_COORDINATOR_REGION = "{gcp region for secondary}"

  // Workload Identity Configuration
  GCP_PRIMARY_WORKLOAD_IDENTITY_POOL_PROVIDER = "{workload_identity_pool_provider_name from operator_wipp primary}"
  GCP_SECONDARY_WORKLOAD_IDENTITY_POOL_PROVIDER = "{workload_identity_pool_provider_name from operator_wipp secondary}"
  
  // Cloud Function URLs
  GCP_PRIMARY_KEY_SERVICE_CLOUD_FUNCTION_URL = "{encryption_key_service_cloudfunction_url from mpkhs primary}"
  GCP_SECONDARY_KEY_SERVICE_CLOUD_FUNCTION_URL = "{encryption_key_service_cloudfunction_url from mpkhs secondary}"
  
  // Cache Configuration
  PRIVATE_KEY_CACHE_TTL_SECONDS = "3974400"
  KEY_REFRESH_FLOW_RUN_FREQUENCY_SECONDS = "20000"

  // TLS Configuration
  BFE_TLS_KEY = module.secrets.tls_key
  BFE_TLS_CERT = module.secrets.tls_cert
  
  // Debug URL Configuration
  MAX_ALLOWED_SIZE_DEBUG_URL_BYTES = "65536"
  MAX_ALLOWED_SIZE_ALL_DEBUG_URLS_KB = "3000"

  // Inference Configuration
  INFERENCE_SIDECAR_BINARY_PATH = "/server/bin/inference_sidecar_tensorflow_v2_14_0"
  INFERENCE_MODEL_BUCKET_NAME = "{bucket-for-storing-model}"
  INFERENCE_MODEL_CONFIG_PATH = "model_config.json"
  INFERENCE_MODEL_FETCH_PERIOD_MS = "300000"
  INFERENCE_SIDECAR_RUNTIME_CONFIG = jsonencode({
    "num_interop_threads": 4,
    "num_intraop_threads": 4,
    "module_name": "tensorflow_v2_14_0"
  })

  // TCMalloc Configuration
  BIDDING_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND = "4096"
  BIDDING_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES = "10737418240"
  BFE_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND = "4096"
  BFE_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES = "10737418240"
  BIDDING_SIGNALS_FETCH_MODE = "REQUIRED"
}

// Service Account Configuration
service_account_email = "buyer-stack@{service-acc-email}"
tee_impersonate_service_accounts = "{wip_verified_service_account from operator_wipp secondary},{wip_verified_service_account from operator_wipp secondary}"
```

### 5. Deploy

```bash
cd $REPO_BASE/production/deploy/gcp/terraform/environment/demo/buyer
terraform init
terraform plan
terraform apply
