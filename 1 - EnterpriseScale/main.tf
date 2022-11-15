terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.18.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# provider "azurerm" {
#   alias           = "identity"
#   subscription_id = var.id_sub_id
#   tenant_id       = var.id_ten_id
#   client_id       = var.id_clt_id
#   client_secret   = var.id_sec_id
#   features {}
# }

# provider "azurerm" {
#   alias           = "connectivity"
#   subscription_id = var.con_sub_id
#   tenant_id       = var.con_ten_id
#   client_id       = var.con_clt_id
#   client_secret   = var.con_sec_id
#   features {}
# }

# provider "azurerm" {
#   alias           = "management"
#   subscription_id = var.mgt_sub_id
#   tenant_id       = var.mgt_ten_id
#   client_id       = var.mgt_clt_id
#   client_secret   = var.mgt_sec_id
#   features {}
# }

data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "2.4.1"

  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm
    azurerm.management   = azurerm
  }

  root_parent_id = data.azurerm_client_config.core.tenant_id
  root_id        = var.root_id
  root_name      = var.root_name

  deploy_identity_resources    = var.deploy_identity_resources
  subscription_id_identity     = data.azurerm_client_config.core.subscription_id
  configure_identity_resources = local.configure_identity_resources

  deploy_management_resources    = var.deploy_management_resources
  subscription_id_management     = data.azurerm_client_config.core.subscription_id
  configure_management_resources = local.configure_management_resources
}