# KV service Azure Container Instance for load test.
# Creates resource group, storage account, file share, and ACI.
# Env vars match offer-service Terraform (offer.tf) kv runtime_flags + global_runtime_flags.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  resource_group_name  = "kv-load-test-rg"
  storage_account_name = "kvloadtestaci"
  aci_name             = "kv-load-test"
  file_share_name      = "fslogix"
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_storage_share" "share" {
  name                = local.file_share_name
  storage_account_id  = azurerm_storage_account.sa.id
  quota               = 5120
}

resource "azurerm_storage_share_directory" "deltas" {
  name              = "deltas"
  storage_share_url = "https://${azurerm_storage_account.sa.name}.file.core.windows.net/${azurerm_storage_share.share.name}"
}

resource "azurerm_storage_share_directory" "realtime" {
  name              = "realtime"
  storage_share_url = "https://${azurerm_storage_account.sa.name}.file.core.windows.net/${azurerm_storage_share.share.name}"
}

resource "azurerm_container_group" "kv" {
  depends_on = [azurerm_storage_share_directory.deltas, azurerm_storage_share_directory.realtime]
  name                = local.aci_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  ip_address_type     = "Public"
  restart_policy      = "Never"
  sku                 = "Confidential"

  identity {
    type = "SystemAssigned"
  }

  container {
    name   = local.aci_name
    image  = var.kv_image
    cpu    = var.cpu
    memory = var.memory_gb

    ports {
      port     = 50051
      protocol = "TCP"
    }
    ports {
      port     = 51052
      protocol = "TCP"
    }

    environment_variables = local.kv_env

    volume {
      name                 = "data"
      storage_account_name = azurerm_storage_account.sa.name
      storage_account_key  = azurerm_storage_account.sa.primary_access_key
      share_name           = azurerm_storage_share.share.name
      mount_path           = "/data"
    }
  }
}

# Env vars from offer-service Terraform (offer.tf): kv runtime_flags + global_runtime_flags
locals {
  kv_env = {
    KV_PORT                                   = "50051"
    KV_HEALTHCHECK_PORT                       = "50051"
    AZURE_LOCAL_DATA_DIR                      = "/data/deltas"
    AZURE_LOCAL_REALTIME_DATA_DIR             = "/data/realtime"
    DATA_LOADING_NUM_THREADS                  = "1"
    BUYER_EGRESS_TLS                          = ""
    COLLECTOR_ENDPOINT                        = ""
    CONSENTED_DEBUG_TOKEN                     = "test-token"
    ENABLE_AUCTION_COMPRESSION                = "false"
    ENABLE_BUYER_COMPRESSION                  = "false"
    ENABLE_CHAFFING                           = "false"
    ENABLE_OTEL_BASED_LOGGING                 = "false"
    ENABLE_PROTECTED_APP_SIGNALS              = "false"
    ENABLE_ENCRYPTION                         = "false"
    KV_SERVER_EGRESS_TLS                      = ""
    MAX_ALLOWED_SIZE_DEBUG_URL_BYTES         = "65536"
    MAX_ALLOWED_SIZE_ALL_DEBUG_URLS_KB       = "3000"
    PS_VERBOSITY                             = "10"
    ROMA_TIMEOUT_MS                          = ""
    TELEMETRY_CONFIG                         = "mode: EXPERIMENT"
    AZURE_BA_PARAM_GET_TOKEN_URL             = "http://169.254.169.254/metadata/identity/oauth2/token"
    AZURE_BA_PARAM_CLIENT_ID                 = ""
    AZURE_BA_PARAM_KMS_UNWRAP_URL            = "https://depa-inferencing-kms-azure.ispirt.in/app/unwrapKey?fmt=tink"
    ENABLE_PROTECTED_AUDIENCE                = "true"
    KEY_REFRESH_FLOW_RUN_FREQUENCY_SECONDS   = "10800"
    PRIMARY_COORDINATOR_ACCOUNT_IDENTITY     = ""
    PRIMARY_COORDINATOR_PRIVATE_KEY_ENDPOINT = "https://depa-inferencing-kms-azure.ispirt.in/app/key?fmt=tink"
    PRIMARY_COORDINATOR_REGION               = ""
    PRIVATE_KEY_CACHE_TTL_SECONDS            = "3888000"
    PUBLIC_KEY_ENDPOINT                      = "https://depa-inferencing-kms-azure.ispirt.in/app/listpubkeys"
    TEST_MODE                                = "true"
  }
}
