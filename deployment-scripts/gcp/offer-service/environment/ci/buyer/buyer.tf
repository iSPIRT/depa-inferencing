# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  gcp_project_id = "<gcp_project_id>"
  environment    = "<environment>"
  buyer_operator = "ci-buyer"
  default_region_config = {
    "<gcp_region>" = {
      collector = {
        machine_type          = "e2-micro"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
      }
      backend = {
        machine_type          = "n2d-standard-4"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
      }
      frontend = {
        machine_type          = "n2d-standard-4"
        min_replicas          = 1
        max_replicas          = 1
        zones                 = null
        max_rate_per_instance = null
      }
    }
  }

  frontend_domain_ssl_certificate_id = "<ssl_certificate_id>"
  frontend_certificate_map_id        = ""
  buyer_domain_name                  = "<buyer_domain_name>"
  frontend_dns_zone                  = "<dns_zone>"

  buyer_traffic_splits = {
    "${local.environment}" = {
      traffic_weight        = 1000
      region_config         = local.default_region_config
      runtime_flag_override = {}
    }
  }
}

provider "google" {
  project = local.gcp_project_id
}

provider "google-beta" {
  project = local.gcp_project_id
}

resource "google_compute_project_metadata" "default" {
  project = local.gcp_project_id
  metadata = {
    enable-oslogin = "FALSE"
  }
}

module "secrets" {
  source = "../../../modules/secrets"
}

module "buyer" {
  for_each             = { for key, value in local.buyer_traffic_splits : key => value if value.traffic_weight > 0 }
  source               = "../../../modules/buyer"
  environment          = each.key
  gcp_project_id       = local.gcp_project_id
  bidding_image        = "ispirt.azurecr.io/depainferencing/gcp/bidding_service:nonprod-4.8.0"
  buyer_frontend_image = "ispirt.azurecr.io/depainferencing/gcp/buyer_frontend_service:nonprod-4.8.0"

  runtime_flags = merge({
    BIDDING_PORT                      = "50051"
    BUYER_FRONTEND_PORT               = "50051"
    BUYER_FRONTEND_HEALTHCHECK_PORT   = "50050"
    BIDDING_SERVER_ADDR               = "xds:///bidding"
    BFE_INGRESS_TLS                   = "true"
    BIDDING_EGRESS_TLS                = "false"
    AD_RETRIEVAL_KV_SERVER_EGRESS_TLS = "false"
    KV_SERVER_EGRESS_TLS              = "false"
    TEST_MODE                         = "true"

    ENABLE_BIDDING_SERVICE_BENCHMARK   = "false"
    # Secret Manager rejects empty payloads; use EMPTY_STRING for unset optional flags (see KV demo tfvars).
    BUYER_KV_SERVER_ADDR               = "EMPTY_STRING"
    BUYER_TKV_V2_SERVER_ADDR           = "PLACEHOLDER"
    ENABLE_TKV_V2_BROWSER              = "false"
    TKV_EGRESS_TLS                     = "false"
    TEE_AD_RETRIEVAL_KV_SERVER_ADDR    = "EMPTY_STRING"
    TEE_KV_SERVER_ADDR                 = "EMPTY_STRING"
    AD_RETRIEVAL_TIMEOUT_MS            = "60000"
    GENERATE_BID_TIMEOUT_MS            = "60000"
    BIDDING_SIGNALS_LOAD_TIMEOUT_MS    = "60000"
    ENABLE_BUYER_FRONTEND_BENCHMARKING = "false"
    CREATE_NEW_EVENT_ENGINE            = "false"
    ENABLE_BIDDING_COMPRESSION         = "true"
    ENABLE_PROTECTED_AUDIENCE          = "true"
    PS_VERBOSITY                       = "10"
    ENABLE_PROTECTED_APP_SIGNALS                  = "false"
    PROTECTED_APP_SIGNALS_GENERATE_BID_TIMEOUT_MS = "60000"
    EGRESS_SCHEMA_FETCH_CONFIG                    = "EMPTY_STRING"
    BUYER_CODE_FETCH_CONFIG                       = "EMPTY_STRING"
    UDF_NUM_WORKERS           = "4"
    JS_WORKER_QUEUE_LEN       = "200"
    ROMA_TIMEOUT_MS           = "10000"
    TELEMETRY_CONFIG          = "mode: EXPERIMENT"
    COLLECTOR_ENDPOINT        = "EMPTY_STRING"
    ENABLE_OTEL_BASED_LOGGING = "false"
    CONSENTED_DEBUG_TOKEN     = "EMPTY_STRING"
    DEBUG_SAMPLE_RATE_MICRO   = "0"

    # Coordinator-based attestation flags (ignored in TEST_MODE).
    PUBLIC_KEY_ENDPOINT                           = "https://publickeyservice.pa.gcp.privacysandboxservices.com/.well-known/protected-auction/v1/public-keys"
    PRIMARY_COORDINATOR_PRIVATE_KEY_ENDPOINT      = "https://privatekeyservice-a.pa-3.gcp.privacysandboxservices.com/v1alpha/encryptionKeys"
    SECONDARY_COORDINATOR_PRIVATE_KEY_ENDPOINT    = "https://privatekeyservice-b.pa-4.gcp.privacysandboxservices.com/v1alpha/encryptionKeys"
    PRIMARY_COORDINATOR_ACCOUNT_IDENTITY          = "a-opverifiedusr@ps-pa-coord-prd-g3p-wif.iam.gserviceaccount.com"
    SECONDARY_COORDINATOR_ACCOUNT_IDENTITY        = "b-opverifiedusr@ps-prod-pa-type2-fe82.iam.gserviceaccount.com"
    PRIMARY_COORDINATOR_REGION                    = "us-central1"
    SECONDARY_COORDINATOR_REGION                  = "us-central1"
    GCP_PRIMARY_WORKLOAD_IDENTITY_POOL_PROVIDER   = "projects/732552956908/locations/global/workloadIdentityPools/a-opwip/providers/a-opwip-pvdr"
    GCP_SECONDARY_WORKLOAD_IDENTITY_POOL_PROVIDER = "projects/99438709206/locations/global/workloadIdentityPools/b-opwip/providers/b-opwip-pvdr"
    GCP_PRIMARY_KEY_SERVICE_CLOUD_FUNCTION_URL    = "https://a-us-central1-encryption-key-service-cloudfunctio-j27wiaaz5q-uc.a.run.app"
    GCP_SECONDARY_KEY_SERVICE_CLOUD_FUNCTION_URL  = "https://b-us-central1-encryption-key-service-cloudfunctio-wdqaqbifva-uc.a.run.app"
    PRIVATE_KEY_CACHE_TTL_SECONDS                 = "3974400"
    KEY_REFRESH_FLOW_RUN_FREQUENCY_SECONDS        = "20000"

    BFE_TLS_KEY                        = module.secrets.tls_key
    BFE_TLS_CERT                       = module.secrets.tls_cert
    MAX_ALLOWED_SIZE_DEBUG_URL_BYTES   = "65536"
    MAX_ALLOWED_SIZE_ALL_DEBUG_URLS_KB = "3000"

    INFERENCE_SIDECAR_BINARY_PATH    = "EMPTY_STRING"
    INFERENCE_MODEL_BUCKET_NAME      = "EMPTY_STRING"
    INFERENCE_MODEL_CONFIG_PATH      = "EMPTY_STRING"
    INFERENCE_MODEL_FETCH_PERIOD_MS  = "EMPTY_STRING"
    INFERENCE_SIDECAR_RUNTIME_CONFIG = "EMPTY_STRING"

    BIDDING_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND = "4096"
    BIDDING_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES             = "10737418240"
    BFE_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND     = "4096"
    BFE_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES                 = "10737418240"
  }, each.value.runtime_flag_override)

  frontend_domain_name               = local.buyer_domain_name
  frontend_dns_zone                  = local.frontend_dns_zone
  operator                           = local.buyer_operator
  service_account_email              = "<vm_service_account>"
  vm_startup_delay_seconds           = 200
  cpu_utilization_percent            = 0.6
  use_confidential_space_debug_image = true
  tee_impersonate_service_accounts   = ""
  collector_service_port             = 4317
  collector_startup_script = templatefile("../../../services/autoscaling/collector_startup.tftpl", {
    collector_port           = 4317
    otel_collector_image_uri = "otel/opentelemetry-collector-contrib:0.105.0"
    gcs_hmac_key             = module.secrets.gcs_hmac_key
    gcs_hmac_secret          = module.secrets.gcs_hmac_secret
    gcs_bucket               = ""
    gcs_bucket_prefix        = ""
    file_prefix              = ""
  })
  region_config                     = each.value.region_config
  enable_tee_container_log_redirect = true
}

module "buyer_frontend_load_balancing" {
  source               = "../../../services/frontend_load_balancing"
  environment          = local.environment
  operator             = local.buyer_operator
  frontend_ip_address  = module.buyer[local.environment].frontend_address
  frontend_domain_name = local.buyer_domain_name
  frontend_dns_zone    = local.frontend_dns_zone

  frontend_domain_ssl_certificate_id = local.frontend_domain_ssl_certificate_id
  frontend_certificate_map_id        = local.frontend_certificate_map_id
  frontend_service_name              = "bfe"
  google_compute_backend_service_ids = {
    for buyer_key, buyer in module.buyer :
    buyer_key => buyer.google_compute_backend_service_id
  }
  traffic_weights = { for key, value in local.buyer_traffic_splits : key => value.traffic_weight }
}

module "buyer_dashboard" {
  source      = "../../../services/dashboards/buyer_dashboard"
  environment = join("|", [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0])
}

module "inference_dashboard" {
  source      = "../../../services/dashboards/inference_dashboard"
  environment = join("|", [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0])
}
