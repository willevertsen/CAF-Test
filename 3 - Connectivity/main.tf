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

provider "azurerm" {
  alias           = "management"
  subscription_id = var.mgt_sub_id
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

data "azurerm_log_analytics_workspace" "management_primary" {
  provider = azurerm.management
  name = "ap-management-${local.region_short[var.primary_region]}-law"
  resource_group_name = "ap-management-${local.region_short[var.primary_region]}-rg"
}

data "azurerm_log_analytics_workspace" "management_secondary" {
  provider = azurerm.management
  name = "ap-management-${local.region_short[var.secondary_region]}-law"
  resource_group_name = "ap-management-${local.region_short[var.secondary_region]}-rg"
}

resource "azurerm_resource_group" "connectivity_primary" {
  name     = "ap-connectivity-${local.region_short[var.primary_region]}-rg"
  location = local.approved_regions[var.primary_region]

  tags = local.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_resource_group" "connectivity_secondary" {
  name     = "ap-connectivity-${local.region_short[var.secondary_region]}-rg"
  location = local.approved_regions[var.secondary_region]

  tags = local.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "connectivity_primary" {
  name                     = "apconn${local.region_short[var.primary_region]}salrs01" // TODO: Randomize name.
  resource_group_name      = azurerm_resource_group.connectivity_primary.name
  location                 = azurerm_resource_group.connectivity_primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  blob_properties {
    delete_retention_policy {
      days = var.log_retention
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "connectivity_secondary" {
  name                     = "apcon${local.region_short[var.secondary_region]}salrs01"
  resource_group_name      = azurerm_resource_group.connectivity_secondary.name
  location                 = azurerm_resource_group.connectivity_secondary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  blob_properties {
    delete_retention_policy {
      days = var.log_retention
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_network" "connectivity_primary" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}-vnet01"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name
  address_space       = [var.primary_region_cidr]
  dns_servers         = var.primary_region_dns

  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_network" "connectivity_secondary" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}-vnet01"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name
  address_space       = [var.secondary_region_cidr]
  dns_servers         = var.secondary_region_dns

  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_network_peering" "connectivity_primary_to_secondary" {
  name                      = "peerprimarytosecondary"
  resource_group_name       = azurerm_resource_group.connectivity_primary.name
  virtual_network_name      = azurerm_virtual_network.connectivity_primary.name
  remote_virtual_network_id = azurerm_virtual_network.connectivity_secondary.id
}

resource "azurerm_virtual_network_peering" "connectivity_secondary_to_primary" {
  name                      = "peersecondarytoprimary"
  resource_group_name       = azurerm_resource_group.connectivity_secondary.name
  virtual_network_name      = azurerm_virtual_network.connectivity_secondary.name
  remote_virtual_network_id = azurerm_virtual_network.connectivity_primary.id
}

resource "azurerm_subnet" "connectivity_primary" {
  name                 = "ap-connectivity-${local.region_short[var.primary_region]}-Hub"
  resource_group_name  = azurerm_resource_group.connectivity_primary.name
  virtual_network_name = azurerm_virtual_network.connectivity_primary.name
  address_prefixes     = [var.primary_region_subnet]

  lifecycle {
    ignore_changes = [enforce_private_link_endpoint_network_policies, delegation]
  }
}

resource "azurerm_subnet" "connectivity_primary_gatewaysubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity_primary.name
  virtual_network_name = azurerm_virtual_network.connectivity_primary.name
  address_prefixes     = [var.primary_region_gatewaysubnet]
}

resource "azurerm_subnet" "connectivity_primary_firewallsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity_primary.name
  virtual_network_name = azurerm_virtual_network.connectivity_primary.name
  address_prefixes     = [var.primary_region_firewallsubnet]
}

resource "azurerm_subnet" "connectivity_secondary" {
  name                 = "ap-connectivity-${local.region_short[var.secondary_region]}-Hub"
  resource_group_name  = azurerm_resource_group.connectivity_secondary.name
  virtual_network_name = azurerm_virtual_network.connectivity_secondary.name
  address_prefixes     = [var.secondary_region_subnet]

  lifecycle {
    ignore_changes = [enforce_private_link_endpoint_network_policies, delegation]
  }
}

resource "azurerm_subnet" "connectivity_secondary_gatewaysubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity_secondary.name
  virtual_network_name = azurerm_virtual_network.connectivity_secondary.name
  address_prefixes     = [var.secondary_region_gatewaysubnet]
}

resource "azurerm_subnet" "connectivity_secondary_firewallsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity_secondary.name
  virtual_network_name = azurerm_virtual_network.connectivity_secondary.name
  address_prefixes     = [var.secondary_region_firewallsubnet]
}

resource "azurerm_network_security_group" "connectivity_primary_default" {
  name                = "ap-connectivity-nsg-${local.region_short[var.primary_region]}-default"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name
  
  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_security_group" "connectivity_secondary_default" {
  name                = "ap-connectivity-nsg-${local.region_short[var.secondary_region]}-default"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name

  tags = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet_network_security_group_association" "connectivity_primary_default" {
  subnet_id                 = azurerm_subnet.connectivity_primary.id
  network_security_group_id = azurerm_network_security_group.connectivity_primary_default.id
}

resource "azurerm_subnet_network_security_group_association" "connectivity_secondary_default" {
  subnet_id                 = azurerm_subnet.connectivity_secondary.id
  network_security_group_id = azurerm_network_security_group.connectivity_secondary_default.id
}

resource "azurerm_network_watcher" "connectivity_primary" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}-nw"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name
  tags                = local.tags
}

resource "azurerm_network_watcher_flow_log" "connectivity_primary" {
  network_watcher_name      = "ap-connectivity-${local.region_short[var.primary_region]}-nw"
  name                      = "ap-connectivity-${local.region_short[var.primary_region]}-nwfl"
  resource_group_name       = azurerm_resource_group.connectivity_primary.name
  network_security_group_id = azurerm_network_security_group.connectivity_primary_default.id
  storage_account_id        = azurerm_storage_account.connectivity_primary.id
  enabled                   = true
  tags                      = local.tags

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = data.azurerm_log_analytics_workspace.management_primary.workspace_id
    workspace_region      = data.azurerm_log_analytics_workspace.management_primary.location
    workspace_resource_id = data.azurerm_log_analytics_workspace.management_primary.id
    interval_in_minutes   = 10
  }

  lifecycle {
    ignore_changes = [tags, name]
  }
}

resource "azurerm_network_watcher" "connectivity_secondary" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}nw"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name
  tags                = local.tags
}

resource "azurerm_network_watcher_flow_log" "connectivity_secondary" {
  network_watcher_name      = "ap-connectivity-${local.region_short[var.secondary_region]}nw"
  name                      = "ap-connectivity-${local.region_short[var.secondary_region]}nw"
  resource_group_name       = azurerm_resource_group.connectivity_secondary.name
  network_security_group_id = azurerm_network_security_group.connectivity_secondary_default.id
  storage_account_id        = azurerm_storage_account.connectivity_secondary.id
  enabled                   = true
  tags                      = local.tags

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = data.azurerm_log_analytics_workspace.management_secondary.workspace_id
    workspace_region      = data.azurerm_log_analytics_workspace.management_secondary.location
    workspace_resource_id = data.azurerm_log_analytics_workspace.management_secondary.id
    interval_in_minutes   = 10
  }

  lifecycle {
    ignore_changes = [tags, name]
  }
}

resource "azurerm_public_ip" "connectivity_primary_vgw" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}pip01"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name

  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "connectivity_primary" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}vgw"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name
  type                = "Vpn"

  vpn_type                         = "RouteBased"
  enable_bgp                       = false
  active_active                    = false
  private_ip_address_enabled       = true
  sku                              = "VpnGw2"
  generation                       = "Generation2"
  tags                             = local.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.connectivity_primary_vgw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.connectivity_primary_gatewaysubnet.id
  }
}

resource "azurerm_public_ip" "connectivity_primary_fw" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}pip02"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name

  allocation_method = "Static"
  sku               = "Standard"
  tags              = local.tags
}

resource "azurerm_firewall_policy" "connectivity_primary" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}fwp"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "connectivity_primary" {
  name               = "ap-connectivity-${local.region_short[var.primary_region]}rcg"
  firewall_policy_id = azurerm_firewall_policy.connectivity_primary.id
  priority           = 500

  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "connectivity_primary" {
  name                = "ap-connectivity-${local.region_short[var.primary_region]}fw"
  location            = azurerm_resource_group.connectivity_primary.location
  resource_group_name = azurerm_resource_group.connectivity_primary.name

  sku_name           = "AZFW_VNet"
  sku_tier           = "Standard"
  firewall_policy_id = azurerm_firewall_policy.connectivity_primary.id
  #dns_servers        = var.primary_region_dns
  threat_intel_mode  = "Alert"
  tags               = local.tags

  ip_configuration {
    name                 = "Hub"
    subnet_id            = azurerm_subnet.connectivity_primary_firewallsubnet.id
    public_ip_address_id = azurerm_public_ip.connectivity_primary_fw.id
  }
}

resource "azurerm_public_ip" "connectivity_secondary_vgw" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}pip01"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name

  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "connectivity_secondary" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}vgw"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name
  type                = "Vpn"

  vpn_type                         = "RouteBased"
  enable_bgp                       = false
  active_active                    = false
  private_ip_address_enabled       = true
  sku                              = "VpnGw2"
  generation                       = "Generation2"
  tags                             = local.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.connectivity_secondary_vgw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.connectivity_secondary_gatewaysubnet.id
  }
}

resource "azurerm_public_ip" "connectivity_secondary_fw" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}pip02"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name

  allocation_method = "Static"
  sku               = "Standard"
  tags              = local.tags
}

resource "azurerm_firewall_policy" "connectivity_secondary" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}fwp"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "connectivity_secondary" {
  name               = "ap-connectivity-${local.region_short[var.secondary_region]}rcg"
  firewall_policy_id = azurerm_firewall_policy.connectivity_secondary.id
  priority           = 500

  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "connectivity_secondary" {
  name                = "ap-connectivity-${local.region_short[var.secondary_region]}fw"
  location            = azurerm_resource_group.connectivity_secondary.location
  resource_group_name = azurerm_resource_group.connectivity_secondary.name

  sku_name           = "AZFW_VNet"
  sku_tier           = "Standard"
  firewall_policy_id = azurerm_firewall_policy.connectivity_secondary.id
  #dns_servers        = var.secondary_region_dns
  threat_intel_mode  = "Alert"
  tags               = local.tags

  ip_configuration {
    name                 = "Hub"
    subnet_id            = azurerm_subnet.connectivity_secondary_firewallsubnet.id
    public_ip_address_id = azurerm_public_ip.connectivity_secondary_fw.id
  }
}