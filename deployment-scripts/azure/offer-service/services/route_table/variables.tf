variable "operator" {
  description = "Operator name used to identify the resource owner."
  type        = string
}

variable "environment" {
  description = "Assigned environment name to group related resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "aks_subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "cg_subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "https_proxy_ip"{
  description = "Egress Proxy IP"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

