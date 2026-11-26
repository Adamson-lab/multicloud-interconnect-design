terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "Host project ID for the Shared VPC. REPLACE."
}

variable "region" {
  type    = string
  default = "europe-west4" # REPLACE
}

variable "network" {
  type        = string
  description = "VPC network self-link or name. REPLACE."
  default     = "shared-vpc-prod"
}

variable "router_asn" {
  type        = number
  description = "Google Cloud Router ASN (private, 64512 to 65534). REPLACE."
  default     = 64514
}

variable "partner_interconnect_bandwidth" {
  type    = string
  default = "BPS_1G"
}

variable "edge_availability_domain" {
  type    = string
  default = "AVAILABILITY_DOMAIN_1"
}

resource "google_compute_router" "interconnect" {
  name    = "cr-interconnect-${var.region}"
  project = var.project_id
  region  = var.region
  network = var.network

  bgp {
    asn               = var.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_interconnect_attachment" "partner_a" {
  name                     = "vlan-partner-a-${var.region}"
  project                  = var.project_id
  region                   = var.region
  router                   = google_compute_router.interconnect.id
  type                     = "PARTNER"
  edge_availability_domain = var.edge_availability_domain
  bandwidth                = var.partner_interconnect_bandwidth
  admin_enabled            = true
}

output "pairing_key" {
  value     = google_compute_interconnect_attachment.partner_a.pairing_key
  sensitive = true
}
