# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location

  tags = var.tags
}

