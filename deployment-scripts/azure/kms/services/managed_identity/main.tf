# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "github_actions" {
  count               = var.github_repository != "" ? 1 : 0
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

