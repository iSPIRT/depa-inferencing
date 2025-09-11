# Portions Copyright (c) Microsoft Corporation
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

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.1"
    }
    # Add the helm provider requirement
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    # Add the azuread provider requirement
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.1.0"
}


provider "azuread" {
  use_cli = true
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

