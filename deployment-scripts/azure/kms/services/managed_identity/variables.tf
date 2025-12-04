# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the user-assigned managed identity."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the managed identity is created."
}

variable "location" {
  type        = string
  description = "Azure region for the managed identity."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the managed identity."
  default     = {}
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in format 'owner/repo' for federated credential. Leave empty to disable."
  default     = ""
}

variable "github_branch" {
  type        = string
  description = "GitHub branch name for federated credential. Only used if github_repository is set."
  default     = ""
}

