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
  buyer_traffic_splits = {
    (var.environment) = {
      image_tag             = var.image_tag
      traffic_weight        = var.traffic_weight
      region_config         = var.default_region_config
      runtime_flag_override = var.buyer_runtime_flag_override
    }
  }

  buyer_header_experiment = {
    "${var.environment}-h1" = {
      image_tag             = var.header_experiment_image_tag != "" ? var.header_experiment_image_tag : var.image_tag
      region_config         = var.default_region_config
      runtime_flag_override = var.buyer_runtime_flag_override
      match_rules           = var.header_experiment_match_rules
    }
  }
}

provider "google" {
  project = var.gcp_project_id
}

provider "google-beta" {
  project = var.gcp_project_id
}

resource "google_compute_project_metadata" "default" {
  project = var.gcp_project_id
  metadata = {
    enable-oslogin = "FALSE"
  }
}

# See README.md for instructions on how to use the secrets module.
module "secrets" {
  source = "../../../modules/secrets"
}

module "buyer" {
  for_each = merge(
    { for key, value in local.buyer_traffic_splits :
    key => value if value.traffic_weight > 0 },
    { for key, value in local.buyer_header_experiment :
    key => value if length(value.match_rules) > 0 }
  )

  source               = "../../../modules/buyer"
  environment          = each.key
  gcp_project_id       = var.gcp_project_id
  bidding_image        = "${var.image_repo}/bidding_service:${each.value.image_tag}"
  buyer_frontend_image = "${var.image_repo}/buyer_frontend_service:${each.value.image_tag}"

  runtime_flags = merge({
    BIDDING_PORT                      = "50051"          # Do not change unless you are modifying the default GCP architecture.
    BUYER_FRONTEND_PORT               = "50051"          # Do not change unless you are modifying the default GCP architecture.
    BUYER_FRONTEND_HEALTHCHECK_PORT   = "50050"          # Do not change unless you are modifying the default GCP architecture.
    BIDDING_SERVER_ADDR               = "xds:///bidding" # Do not change unless you are modifying the default GCP architecture.
    BFE_INGRESS_TLS                   = "true"           # Do not change unless you are modifying the default GCP architecture.
    BIDDING_EGRESS_TLS                = "false"          # Do not change unless you are modifying the default GCP architecture.
    AD_RETRIEVAL_KV_SERVER_EGRESS_TLS = "false"          # Do not change unless you are modifying the default GCP architecture.
    KV_SERVER_EGRESS_TLS              = "false"          # Do not change unless you are modifying the default GCP architecture.
    TEST_MODE                         = var.test_mode    # Do not change unless you are testing without key fetching.

    ENABLE_BIDDING_SERVICE_BENCHMARK = "true"
    ENABLE_TKV_V2_BROWSER            = "false"
    TKV_EGRESS_TLS                   = "false"
    BUYER_TKV_V2_SERVER_ADDR         = "PLACEHOLDER"
    AD_RETRIEVAL_TIMEOUT_MS          = "60000"

    GENERATE_BID_TIMEOUT_MS                       = "60000"
    BIDDING_SIGNALS_LOAD_TIMEOUT_MS               = "60000"
    ENABLE_BUYER_FRONTEND_BENCHMARKING            = "true"
    CREATE_NEW_EVENT_ENGINE                       = "false"
    ENABLE_BIDDING_COMPRESSION                    = "true"
    ENABLE_PROTECTED_AUDIENCE                     = "true"
    PS_VERBOSITY                                  = "10"
    ENABLE_PROTECTED_APP_SIGNALS                  = "false"
    PROTECTED_APP_SIGNALS_GENERATE_BID_TIMEOUT_MS = "60000"
    BUYER_CODE_FETCH_CONFIG = jsonencode({
      fetchMode                                  = 1
      biddingJsPath                              = ""
      biddingJsUrl                               = ""
      protectedAppSignalsBiddingJsUrl            = ""
      biddingWasmHelperUrl                       = ""
      protectedAppSignalsBiddingWasmHelperUrl    = ""
      urlFetchPeriodMs                           = 13000000
      urlFetchTimeoutMs                          = 30000
      enableBuyerDebugUrlGeneration              = true
      prepareDataForAdsRetrievalJsUrl            = ""
      prepareDataForAdsRetrievalWasmHelperUrl    = ""
      enablePrivateAggregateReporting            = false
      protectedAuctionBiddingJsBucket            = var.buyer_code_bucket
      protectedAuctionBiddingJsBucketDefaultBlob = var.buyer_code_blob
    })
    UDF_NUM_WORKERS           = "2"
    JS_WORKER_QUEUE_LEN       = "100"
    ROMA_TIMEOUT_MS           = "120000"
    TELEMETRY_CONFIG          = "mode: EXPERIMENT"
    COLLECTOR_ENDPOINT        = "localhost:4317"
    ENABLE_OTEL_BASED_LOGGING = "false"
    CONSENTED_DEBUG_TOKEN     = var.consented_debug_token
    DEBUG_SAMPLE_RATE_MICRO   = "0"

    # Coordinator/KMS flags — If TEST_MODE=true then these are not actually used,
    # but they must be present for the config client.
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

    BFE_TLS_KEY                        = module.secrets.tls_key  # You may remove the secrets module and instead either inline or use an auto.tfvars for this variable.
    BFE_TLS_CERT                       = module.secrets.tls_cert # You may remove the secrets module and instead either inline or use an auto.tfvars for this variable.
    MAX_ALLOWED_SIZE_DEBUG_URL_BYTES   = "65536"
    MAX_ALLOWED_SIZE_ALL_DEBUG_URLS_KB = "3000"

    # Inference flags: I fnot using inference sidecar, omit INFERENCE_SIDECAR_BINARY_PATH
    # entirely so the config client returns "" → enable_inference=false → no sandbox start.
    # Other optional inference flags are also omitted to avoid space-as-value
    # issues with Secret Manager (which rejects empty payloads).
    #INFERENCE_SIDECAR_BINARY_PATH            = "" # Example: "/server/bin/inference_sidecar_<module_name>"
    #INFERENCE_MODEL_BUCKET_NAME              = "" # Example: "<bucket_name>"
    #INFERENCE_MODEL_CONFIG_PATH              = "" # Example: "model_config.json"
    #INFERENCE_MODEL_FETCH_PERIOD_MS          = "" # Example: "300000"
    #INFERENCE_SIDECAR_RUNTIME_CONFIG         = "" # Example:
    INFERENCE_MODEL_REGISTRATION_TIMEOUT_MS  = "60000"
    INFERENCE_MODEL_EXECUTION_TIMEOUT_MS     = "60000"
    INFERENCE_MODEL_PATHS_REQUEST_TIMEOUT_MS = "60000"
    INFERENCE_ENABLE_PROTO_PARSING           = "false"
    INFERENCE_ENABLE_CANCELLATION_AT_BIDDING = "false"

    # TCMalloc related config parameters.
    # See: https://github.com/google/tcmalloc/blob/master/docs/tuning.md
    BIDDING_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND = "4096"        # Example: 4096
    BIDDING_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES             = "10737418240" # Example: 10737418240
    BFE_TCMALLOC_BACKGROUND_RELEASE_RATE_BYTES_PER_SECOND     = "4096"
    BFE_TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES                 = "10737418240"
    BIDDING_SIGNALS_FETCH_MODE                                = "NOT_FETCHED"

    ###### [BEGIN] Libcurl parameters.
    #
    # Libcurl is used in frontend servers to fetch real time signals for BYOS
    # KVs in the request path, as well as to fetch UDF blobs off the request
    # path in the backend servers. The following params should be tuned based
    # on the expected load to support, the capacity of the servers and expected
    # size of data/signals/blob to be transfered.
    #
    # Number of curl workers to use in BFE/bidding to run transfers using curl
    # handles. This number should be scaled based on number of vCPUs available
    # to the instance. Note: 1. Each worker uses one thread. 2. Performance
    # degradation has been observed when using more than 4 workers.
    CURL_BFE_NUM_WORKERS     = 4
    CURL_BIDDING_NUM_WORKERS = 1 # Recommended to keep it 1.
    #
    # Maximum wait time for a curl request to be allowed in the queue. After
    # this time expires, the request is removed from the queue and the original
    # request to the service will fail. Setting this value too low can lead to
    # degraded performance in B&A stack under load since lower values increase
    # lock contention.
    CURL_BFE_QUEUE_MAX_WAIT_MS     = 1000
    CURL_BIDDING_QUEUE_MAX_WAIT_MS = 2000
    #
    # Number of pending curl requests that have not yet been scheduled to run.
    # This should be scaled depending on the stack capacity, intended QPS,
    # max wait time limit imposed on the requests in the queue etc.
    CURL_BFE_WORK_QUEUE_LENGTH     = 1000
    CURL_BIDDING_WORK_QUEUE_LENGTH = 10 # Recommended to keep it 10.
    #
    # Constrains the size of the libcurl connection cache.
    # 0 is default, means unlimited.
    # See https://curl.se/libcurl/c/CURLMOPT_MAXCONNECTS.html.
    CURLMOPT_MAXCONNECTS = 0
    # Sets the maximum number of simultaneously open connections.
    # 0 is default, means unlimited.
    # See https://curl.se/libcurl/c/CURLMOPT_MAX_TOTAL_CONNECTIONS.html.
    CURLMOPT_MAX_TOTAL_CONNECTIONS = 0
    # Sets the maximum number of connections to a single host.
    # 0 is default, means unlimited.
    # See: https://curl.se/libcurl/c/CURLMOPT_MAX_HOST_CONNECTIONS.html.
    CURLMOPT_MAX_HOST_CONNECTIONS = 0
    #
    ###### [END] Libcurl parameters.
  }, each.value.runtime_flag_override)

  frontend_domain_name               = var.buyer_domain_name
  frontend_dns_zone                  = var.frontend_dns_zone
  operator                           = var.buyer_operator
  service_account_email              = var.service_account_email
  vm_startup_delay_seconds           = var.vm_startup_delay_seconds
  cpu_utilization_percent            = var.cpu_utilization_percent
  use_confidential_space_debug_image = var.use_confidential_space_debug_image
  tee_impersonate_service_accounts   = var.tee_impersonate_service_accounts
  collector_service_port             = 4317
  collector_startup_script = templatefile("../../../services/autoscaling/collector_startup.tftpl", {
    collector_port           = 4317
    otel_collector_image_uri = "otel/opentelemetry-collector-contrib:0.105.0"
    gcs_hmac_key             = module.secrets.gcs_hmac_key
    gcs_hmac_secret          = module.secrets.gcs_hmac_secret
    gcs_bucket               = "" # Example: ${name of a gcs bucket}
    gcs_bucket_prefix        = "" # Example: "consented-eventmessage-${each.key}"
    file_prefix              = "" # Example: var.buyer_operator
  })
  region_config                     = each.value.region_config
  enable_tee_container_log_redirect = true
}

module "buyer_frontend_load_balancing" {
  source                = "../../../services/frontend_load_balancing"
  environment           = var.environment
  operator              = var.buyer_operator
  frontend_ip_address   = module.buyer[var.environment].frontend_address
  frontend_ipv6_address = module.buyer[var.environment].frontend_ipv6_address
  frontend_domain_name  = var.buyer_domain_name
  frontend_dns_zone     = var.frontend_dns_zone

  frontend_domain_ssl_certificate_id = var.frontend_domain_ssl_certificate_id
  frontend_certificate_map_id        = var.frontend_certificate_map_id
  frontend_ssl_policy_id             = var.frontend_ssl_policy_id
  frontend_service_name              = "bfe"
  google_compute_backend_service_ids = {
    for buyer_key, buyer in module.buyer :
    buyer_key => buyer.google_compute_backend_service_id
  }
  traffic_weights        = { for key, value in local.buyer_traffic_splits : key => value.traffic_weight if value.traffic_weight > 0 }
  experiment_match_rules = { for key, value in local.buyer_header_experiment : key => value.match_rules if length(value.match_rules) > 0 }
}

module "buyer_dashboard" {
  source = "../../../services/dashboards/buyer_dashboard"
  environment = join("|", concat(
    [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0],
  [for k, v in local.buyer_header_experiment : k if length(v.match_rules) > 0]))
}

module "inference_dashboard" {
  source = "../../../services/dashboards/inference_dashboard"
  environment = join("|", concat(
    [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0],
  [for k, v in local.buyer_header_experiment : k if length(v.match_rules) > 0]))
}

module "roma_dashboard" {
  source = "../../../services/dashboards/roma_dashboard"
  environment = join("|", concat(
    [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0],
  [for k, v in local.buyer_header_experiment : k if length(v.match_rules) > 0]))
}

module "k_anon_dashboard" {
  source = "../../../services/dashboards/k_anon_dashboard"
  environment = join("|", concat(
    [for k, v in local.buyer_traffic_splits : k if v.traffic_weight > 0],
  [for k, v in local.buyer_header_experiment : k if length(v.match_rules) > 0]))
}

module "log_based_metric" {
  source      = "../../../services/log_based_metric"
  environment = var.environment
}

# use below to perform an in-place upgrade from pre 4.2 to 4.2 and after, replace $ENV with var.environment value
# moved {
#   from = module.buyer
#   to   = module.buyer["$ENV"]
# }
# moved {
#   from = module.buyer["$ENV"].module.load_balancing.google_compute_url_map.default
#   to   = module.buyer_frontend_load_balancing.google_compute_url_map.default
# }
# moved {
#   from = module.buyer["$ENV"].module.load_balancing.google_compute_target_https_proxy.default
#   to   = module.buyer_frontend_load_balancing.google_compute_target_https_proxy.default
# }
# moved {
#   from = module.buyer["$ENV"].module.load_balancing.google_compute_global_forwarding_rule.xlb_https
#   to   = module.buyer_frontend_load_balancing.google_compute_global_forwarding_rule.xlb_https
# }
# moved {
#   from = module.buyer["$ENV"].module.load_balancing.google_dns_record_set.default
#   to   = module.buyer_frontend_load_balancing.google_dns_record_set.default
# }
# moved {
#   from = module.buyer["$ENV"].module.buyer_dashboard
#   to   = module.buyer_dashboard
# }
# moved {
#   from = module.buyer["$ENV"].module.inference_dashboard
#   to   = module.inference_dashboard
# }
