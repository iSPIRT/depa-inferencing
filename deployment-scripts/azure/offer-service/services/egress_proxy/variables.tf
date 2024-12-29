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

variable "frontend_service_name" {
  type = string
}

variable "region_short" {
  description = "Azure region shorthand"
  type        = string
}

variable "vnet_address_space" {
  description = "VNET address space"
  type        = string
  default     = "10.8.0.0/14"
}

variable "subnet_cidr"{
  description = "subnet address space"
  type        = string
  default     = "10.8.0.0/24"

}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "aks_vnet_name" {
  description = "AKS vnet name"
  type        = string
}

variable "aks_vnet_id" {
  description = "AKS vnet id"
  type        = string
}
