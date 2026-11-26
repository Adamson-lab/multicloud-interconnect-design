terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  type    = string
  default = "rg-multicloud-interconnect" # REPLACE
}

variable "location" {
  type    = string
  default = "westeurope" # REPLACE
}

variable "service_provider_name" {
  type        = string
  description = "ExpressRoute partner name as listed by Azure. REPLACE."
}

variable "peering_location" {
  type        = string
  description = "Peering location, for example Amsterdam. REPLACE."
}

variable "bandwidth_in_mbps" {
  type    = number
  default = 1000
}

variable "peer_asn" {
  type        = number
  description = "Enterprise BGP ASN. REPLACE."
}

variable "primary_peer_address_prefix" {
  type        = string
  description = "/30 for primary link. REPLACE."
}

variable "secondary_peer_address_prefix" {
  type        = string
  description = "/30 for secondary link. REPLACE."
}

variable "vlan_id" {
  type    = number
  default = 400 # REPLACE
}

variable "virtual_network_gateway_id" {
  type        = string
  description = "Existing ExpressRoute-enabled virtual network gateway ID in the hub VNet. REPLACE."
}

resource "azurerm_resource_group" "interconnect" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_express_route_circuit" "this" {
  name                  = "erc-multicloud-primary"
  resource_group_name   = azurerm_resource_group.interconnect.name
  location              = azurerm_resource_group.interconnect.location
  service_provider_name = var.service_provider_name
  peering_location      = var.peering_location
  bandwidth_in_mbps     = var.bandwidth_in_mbps

  sku {
    tier   = "Standard"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_peering" "private" {
  peering_type                  = "AzurePrivatePeering"
  express_route_circuit_name    = azurerm_express_route_circuit.this.name
  resource_group_name           = azurerm_resource_group.interconnect.name
  peer_asn                      = var.peer_asn
  primary_peer_address_prefix   = var.primary_peer_address_prefix
  secondary_peer_address_prefix = var.secondary_peer_address_prefix
  vlan_id                       = var.vlan_id
}

resource "azurerm_virtual_network_gateway_connection" "hub" {
  name                       = "conn-erc-hub"
  location                   = azurerm_resource_group.interconnect.location
  resource_group_name        = azurerm_resource_group.interconnect.name
  type                       = "ExpressRoute"
  virtual_network_gateway_id = var.virtual_network_gateway_id
  express_route_circuit_id   = azurerm_express_route_circuit.this.id
}

output "express_route_circuit_service_key" {
  value     = azurerm_express_route_circuit.this.service_key
  sensitive = true
}
