# Variables for KV service ACI (used by kv_test_aci workflow).
# Terraform creates resource group, storage account, file share, and ACI.

variable "location" {
  type        = string
  default     = "centralindia"
  description = "Azure region for all resources."
}

variable "kv_image" {
  type        = string
  default     = "ispirt.azurecr.io/depainferencing/azure/key-value-service:nonprod-1.2.0.4"
  description = "KV service container image (e.g. ispirt.azurecr.io/.../key-value-service:tag)."
}

variable "cpu" {
  type        = number
  default     = 4
  description = "CPU cores for the container."
}

variable "memory_gb" {
  type        = number
  default     = 16
  description = "Memory in GB for the container."
}
