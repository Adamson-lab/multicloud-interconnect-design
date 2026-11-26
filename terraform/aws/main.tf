terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "eu-west-1" # REPLACE with your region
}

variable "dx_connection_id" {
  type        = string
  description = "Existing Direct Connect connection ID, for example dxcon-xxxxxxxx. REPLACE."
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit Gateway ID that carries prod VPC traffic. REPLACE."
}

variable "vlan" {
  type    = number
  default = 300 # REPLACE with VLAN agreed with the colocation provider
}

variable "amazon_side_asn" {
  type    = number
  default = 64512
}

variable "customer_bgp_asn" {
  type        = number
  description = "Enterprise BGP ASN. REPLACE."
}

variable "allowed_prefixes" {
  type        = list(string)
  description = "Summarised RFC1918 prefixes to advertise to AWS. REPLACE."
  default     = ["10.0.0.0/8"]
}

resource "aws_dx_gateway" "this" {
  name            = "multicloud-dxgw"
  amazon_side_asn = var.amazon_side_asn
}

resource "aws_dx_private_virtual_interface" "primary" {
  connection_id  = var.dx_connection_id
  name           = "multicloud-private-vif-primary"
  vlan           = var.vlan
  address_family = "ipv4"
  bgp_asn        = var.customer_bgp_asn
  dx_gateway_id  = aws_dx_gateway.this.id
  mtu            = 1500
}

resource "aws_dx_gateway_association" "tgw" {
  dx_gateway_id         = aws_dx_gateway.this.id
  associated_gateway_id = var.transit_gateway_id
  allowed_prefixes      = var.allowed_prefixes
}

output "dx_gateway_id" {
  value = aws_dx_gateway.this.id
}
