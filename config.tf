# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# readme.md created with https://terraform-docs.io/: terraform-docs markdown --sort=false ./ > ./readme.md

terraform {
    required_providers {
        oci = {
            source = "oracle/oci"
        }
    }
}

// metadata for the tenancy
data "oci_identity_tenancy" "resident" { tenancy_id = var.account.tenancy_id }

locals {
  defined_tags = {
    for tag in var.configuration.resident.service.tags : "${tag.namespace}.${tag.name}" => tag.default
    if tag.stage <= var.configuration.resident.stage
  }
  freeform_tags = {
    "framework" = "ocloud"
    "owner"     = var.configuration.resident.owner
    "lifecycle" = var.configuration.resident.stage
    "class"     = var.account.class
  }
}

// --- define the wait state 
resource "null_resource" "previous" {}

// this resource will destroy (potentially immediately) after null_resource.next
resource "time_sleep" "wait" {
  depends_on      = [null_resource.previous]
  create_duration = "2m"
}