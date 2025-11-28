# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

