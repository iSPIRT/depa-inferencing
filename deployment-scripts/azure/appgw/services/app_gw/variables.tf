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
  description = "Operator name used to identify the resource owner."
  type        = string
}

variable "environment" {
  description = "Assigned environment name to group related resources."
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "region_short" {
  description = "Azure region shorthand"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "public_ip_address_id" {
  description = "Application gateway public ip id"
  type        = string
}

variable "subnet_id" {
  description = "Application gateway subnet"
  type        = string
}

variable "frontend_service_name" {
  description = "Name of the service"
  type        = string
}

variable "frontend_service_ip" {
  description = "Internal IP of frontend service"
  type        = string
}

variable "certificate_secret_id" {
  description = "Application gateway server authentication certificate secret"
  type        = string
}

variable "user_identity_id" {
  description = "User assigned managed identity for accessing key vault"
  type        = string
}

variable "vnet_name" {
  description = "vnet in which appgw is deployed"
}

variable "vnet_id" {
  description = "vnet id of the appgw vnet"
}

variable "backend_vnet_name" {
  description = "vnet in which backend services have been deployed"
}

variable "backend_vnet_id" {
  description = "vnet id in which backend services have been deployed"
}