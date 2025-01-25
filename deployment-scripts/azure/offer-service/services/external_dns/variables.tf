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

variable "operator" {
  description = "Operator"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]*$", var.operator))
    error_message = "The input_variable can only contain alphanumeric characters (a-z, A-Z, 0-9)."
  }
}

variable "environment" {
  description = "Environment"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]*$", var.environment))
    error_message = "The input_variable can only contain alphanumeric characters (a-z, A-Z, 0-9)."
  }
}

variable "frontend_service_name" {
  type = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "region_short" {
  description = "Azure region short name"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]*$", var.region_short))
    error_message = "The input_variable can only contain alphanumeric characters (a-z, A-Z, 0-9)."
  }
}

variable "private_domain_name" {
  description = "Azure Private DNS domain name"
  type        = string
  default     = "ad_selection.microsoft"
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "vnet_id" {
  description = "Virtual network ID"
  type        = string
}

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
}

variable "aks_cluster_name" {
  description = "Azure Kubernetes Service cluster name"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "Azure Kubernetes Service OIDC issuer URL"
  type        = string
}

variable "kubernetes_namespace" {
  description = "External DNS namespace"
  type        = string
  default     = "external-dns"
}

variable "kubernetes_service_account" {
  description = "External DNS service account name"
  type        = string
  default     = "external-dns"
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "storage_private_ip" {
  description = "IP address of the private connection to storage endpoint"
  type        = string
}