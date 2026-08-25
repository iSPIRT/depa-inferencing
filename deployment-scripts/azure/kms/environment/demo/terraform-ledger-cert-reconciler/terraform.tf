# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Authentication comes from the ambient Azure CLI / environment (az login).
# This root manages ONLY the ledger cert reconciler add-on and keeps its own
# state, fully isolated from the phase-3 gateway deployment.
provider "azurerm" {
  features {}
}
