# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
}

