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
data "oci_identity_tenancy" "resident" { tenancy_id = var.tenancy.id }

locals {
  defined_tags = {
    for tag in var.resident.tags : "${tag.namespace}.${tag.name}" => tag.default
    if tag.stage <= var.resident.stage
  }
  freeform_tags = {
    "framework" = "ocloud"
    "owner"     = var.resident.owner
    "lifecycle" = var.resident.stage
    "class"     = var.tenancy.class
  }
  policies       = jsondecode(templatefile("${path.module}/resident/policies.json", {
    resident     = oci_identity_compartment.resident.name,
    application  = "${oci_identity_compartment.resident.name}_application_compartment",
    network      = "${oci_identity_compartment.resident.name}_network_compartment",
    database     = "${oci_identity_compartment.resident.name}_database_compartment",
    #session_username = var.account.user_id,
    tenancy_OCID = var.tenancy.id,
    #image_OCID   = "${local.service_name}_image_OCID",
    #vault_OCID   = "${local.service_name}_vault_OCID",
    #key_OCID     = "${local.service_name}_key_OCID",
    #stream_OCID  = "${local.service_name}_stream_OCID",
    #workspace_OCID = "${local.service_name}_workspace_OCID",
  }))
}

// --- define the wait state 
resource "null_resource" "previous" {}

// this resource will destroy (potentially immediately) after null_resource.next
resource "time_sleep" "wait" {
  depends_on      = [null_resource.previous]
  create_duration = "2m"
}