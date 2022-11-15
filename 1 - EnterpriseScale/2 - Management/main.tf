terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = [azurerm]
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  tags = {
    "ManagedBy"       = var.managedby
  }
  approved_regions = {
    "East US 2"    = "eastus2"
    "Central US"   = "centralus"
  }
  region_short = {
    "East US 2"    = "eu2"
    "Central US"   = "cus"
  }
}

# You can use the azurerm_client_config data resource to dynamically
# extract the current Tenant ID from your connection settings.

data "azurerm_client_config" "current" {
}

data "azurerm_subscription" "primary" {
}

resource "azurerm_resource_group" "management_primary" {
  name     = "ap-management-${local.region_short[var.primary_region]}-rg"
  location = local.approved_regions[var.primary_region]

  tags = local.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_resource_group" "management_secondary" {
  name     = "ap-management-${local.region_short[var.secondary_region]}-rg"
  location = local.approved_regions[var.secondary_region]

  tags = local.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_log_analytics_workspace" "management_primary" {
  name                = "ap-management-${local.region_short[var.primary_region]}-law"
  resource_group_name = azurerm_resource_group.management_primary.name
  location            = azurerm_resource_group.management_primary.location

  sku                        = "PerGB2018"
  retention_in_days          = var.log_retention
  tags                       = local.tags
}

resource "azurerm_log_analytics_workspace" "management_secondary" {
  name                = "ap-management-${local.region_short[var.secondary_region]}-law"
  resource_group_name = azurerm_resource_group.management_secondary.name
  location            = azurerm_resource_group.management_secondary.location

  sku                        = "PerGB2018"
  retention_in_days          = var.log_retention
  tags                       = local.tags
}

resource "azurerm_log_analytics_solution" "management_primary" {
  for_each = toset(var.law_solutions)

  solution_name         = each.value
  location              = azurerm_resource_group.management_primary.location
  resource_group_name   = azurerm_resource_group.management_primary.name
  workspace_resource_id = azurerm_log_analytics_workspace.management_primary.id
  workspace_name        = azurerm_log_analytics_workspace.management_primary.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }

  tags = local.tags
}

resource "azurerm_log_analytics_solution" "management_secondary" {
  for_each = toset(var.law_solutions)

  solution_name         = each.value
  location              = azurerm_resource_group.management_secondary.location
  resource_group_name   = azurerm_resource_group.management_secondary.name
  workspace_resource_id = azurerm_log_analytics_workspace.management_secondary.id
  workspace_name        = azurerm_log_analytics_workspace.management_secondary.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }

  tags = local.tags
}

resource "azurerm_automation_account" "management_primary" {
  name                = "ap-management-${local.region_short[var.secondary_region]}-aa"
  location            = azurerm_resource_group.management_primary.location
  resource_group_name = azurerm_resource_group.management_primary.name


  sku_name = "Basic"
  tags     = local.tags
}

resource "azurerm_automation_account" "management_secondary" {
  name                = "ap-management-${local.region_short[var.secondary_region]}-aa"
  location            = azurerm_resource_group.management_secondary.location
  resource_group_name = azurerm_resource_group.management_secondary.name


  sku_name = "Basic"
  tags     = local.tags
}

resource "azurerm_log_analytics_linked_service" "management_primary" {
  resource_group_name = azurerm_resource_group.management_primary.name
  workspace_id        = azurerm_log_analytics_workspace.management_primary.id
  read_access_id      = azurerm_automation_account.management_primary.id
}

resource "azurerm_log_analytics_linked_service" "management_secondary" {
  resource_group_name = azurerm_resource_group.management_secondary.name
  workspace_id        = azurerm_log_analytics_workspace.management_secondary.id
  read_access_id      = azurerm_automation_account.management_secondary.id
}
