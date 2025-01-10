
# Updated AKS Configuration (No changes here, included for context)
resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-aks"
  location                  = var.region
  resource_group_name       = var.resource_group_name
  dns_prefix                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-aks-dns"
  kubernetes_version        = var.kubernetes_version
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  automatic_upgrade_channel = "patch"

  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    network_data_plane = "azure"
    load_balancer_sku  = "standard"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    outbound_type      = "userDefinedRouting"
    service_cidrs      = [var.service_cidr]
  }

  default_node_pool {
    name           = "default"
    node_count     = var.node_pool_settings.node_count
    vm_size        = var.node_pool_settings.vm_size
    os_sku         = "Ubuntu"
    vnet_subnet_id = var.subnet_id

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    var.aks_subnet_rtbl_assoc_id
  ]
}

resource "azurerm_role_assignment" "aks_identity_rg_contributor" {
  principal_id                     = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name             = "Contributor"
  scope                            = var.resource_group_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_kubernetes_cluster.aks,
  ]
}

resource "azurerm_role_assignment" "aks_identity_vnet_reader" {
  principal_id                     = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name             = "Reader"
  scope                            = var.virtual_network_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_kubeidentity_rg_contributor" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "Contributor"
  scope                            = var.resource_group_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_kubeidentity_mcrg_contributor" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "Contributor"
  scope                            = azurerm_kubernetes_cluster.aks.node_resource_group_id
  skip_service_principal_aad_check = true
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "virtual-node-identity"
  location            = var.region
  resource_group_name = var.resource_group_name
}
