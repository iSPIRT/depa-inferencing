# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "github_actions" {
  count               = var.github_repository != "" && var.github_branch != "" ? 1 : 0
  name                = "${var.name}-github-actions"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.this.id
  subject             = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"

  depends_on = [
    azurerm_user_assigned_identity.this,
  ]
}

resource "azurerm_federated_identity_credential" "github_environment" {
  for_each                  = var.github_repository != "" ? toset(var.github_environments) : toset([])
  name                      = "${var.name}-github-env-${lower(each.value)}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  subject                   = "repo:${var.github_repository}:environment:${each.value}"

  # Azure rejects concurrent federated credential writes on the same identity.
  depends_on = [
    azurerm_federated_identity_credential.github_actions,
  ]
}

