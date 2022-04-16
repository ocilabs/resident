# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// --- service resident --- //
resource "oci_identity_compartment" "resident" {
  compartment_id = var.options.parent_id
  name           = var.configuration.resident.name
  description    = "compartment that encapsulates all resources for a service"
  enable_delete  = var.options.enable_delete
  freeform_tags  = local.freeform_tags
}
// --- service resident --- //


// --- administrator domains --- //
resource "oci_identity_compartment" "domains" {
  depends_on     = [
    oci_identity_compartment.resident
  ]
  compartment_id = oci_identity_compartment.resident.id
  for_each       = {
    for compartment, stage in var.configuration.resident.compartments : compartment => stage
    if stage <= var.configuration.resident.stage
  }
  name           = each.key
  description    = "${each.key} management domain for ${var.configuration.resident.name}"
  enable_delete  = var.options.enable_delete 
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
}
// --- administrator domains --- //

// --- resource tags --- //
resource "oci_identity_tag_namespace" "resident" {
  depends_on     = [ oci_identity_compartment.resident ]
  compartment_id = oci_identity_compartment.resident.id
  freeform_tags  = local.freeform_tags
  for_each = {
    for namespace, stage in var.configuration.resident.tag_namespaces : namespace => stage
    if stage <= var.configuration.resident.stage
  }
  name        = each.key
  description = "${each.key} tag collection for service ${var.configuration.resident.name}"
}

resource "oci_identity_tag" "resident" {
  depends_on       = [ oci_identity_tag_namespace.resident ]
  for_each         = {
    for tag in var.configuration.resident.tags : tag.name => tag
    if tag.stage <= var.configuration.resident.stage
  }
  name             = each.key
  tag_namespace_id = oci_identity_tag_namespace.resident[each.value.namespace].id
  is_cost_tracking = each.value.cost_tracking
  description      = "defined tag for ${var.configuration.resident.name}"
  is_retired       = false
  freeform_tags  = local.freeform_tags
}

resource "oci_identity_tag_default" "resident" {
  depends_on        = [ oci_identity_tag.resident ]
  compartment_id    = oci_identity_compartment.resident.id
  for_each         = {
    for tag in var.configuration.resident.tags : tag.name => tag
    if tag.stage <= var.configuration.resident.stage
  }
  tag_definition_id = oci_identity_tag.resident[each.key].id
  value             = each.value.default
}
// --- resource tags --- //

// --- operator roles --- //
resource "oci_identity_group" "resident" {
  depends_on     = [
    oci_identity_compartment.resident, 
    oci_identity_tag.resident, 
    oci_identity_tag_namespace.resident, 
    oci_identity_tag.resident, 
    oci_identity_tag_default.resident,
    oci_ons_notification_topic.resident,
    oci_ons_subscription.resident
  ]
  compartment_id = var.configuration.tenancy.id
  for_each       = var.configuration.resident.groups
  name           = each.value
  description    = "group for the ${each.key} role"
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
}
// --- operator roles --- //

// --- policies --- //
resource "oci_identity_policy" "domains" {
  depends_on     = [oci_identity_compartment.domains]
  for_each       = var.configuration.resident.policies
  compartment_id = oci_identity_compartment.resident.id
  name           = each.value.name
  description    = "policies for the ${each.key} role"
  statements     = each.value.rules
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
}
// --- policies --- //

/*/ --- budget controls ---//
resource "oci_budget_budget" "resident" {
  depends_on     = [oci_identity_compartment.resident]
  for_each       = {
    for budget in var.configuration.resident.budgets : budget.display_name => budget
    if budget.stage <= var.configuration.resident.stage
  }
  amount         = each.value.amount
  budget_processing_period_start_offset = 10
  compartment_id = var.configuration.tenancy.id
  defined_tags   = local.defined_tags
  description    = "Set budget the ${var.configuration.resident.name}"
  display_name   = "${var.configuration.resident.name}_budget"
  freeform_tags  = local.freeform_tags
  reset_period   = each.value.reset_period
  target_type    = each.value.target_type
  targets        = [oci_identity_compartment.resident.id]
}

resource "oci_budget_alert_rule" "resident" {
  depends_on     = [oci_budget_budget.resident]
  for_each       = {
    for budget in var.configuration.resident.budgets : budget.display_name => budget
    if budget.stage <= var.configuration.resident.stage
  }
  budget_id      = oci_budget_budget.resident[each.key].id
  defined_tags   = local.defined_tags
  description    = "Inform admins about the budget violations for ${var.configuration.resident.name}"
  display_name   = "${var.configuration.resident.name}_budget_alert"
  freeform_tags  = local.freeform_tags
  threshold      = each.value.threshold
  threshold_type = each.value.threshold_type
  type           = "ACTUAL"
  message        = "${each.value.threshold} % of the monthly budget for ${var.configuration.resident.name} exhausted"
  recipients     = var.configuration.resident.owner
}
// --- budget controls ---/*/

// --- notification service --- //
resource "oci_ons_notification_topic" "resident" {
  depends_on     = [
    oci_identity_compartment.resident,
    oci_identity_tag_namespace.resident,
    oci_identity_tag.resident,
    oci_identity_tag_default.resident,
    time_sleep.wait
  ]
  compartment_id = oci_identity_compartment.resident.id
  for_each       = var.configuration.resident.notifications
  name           = each.value.topic
  description    = "Inform admins about the deployment of ${var.configuration.resident.name}"
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
}

resource "oci_ons_subscription" "resident" {
  depends_on     = [
    oci_identity_compartment.resident, 
    oci_ons_notification_topic.resident, 
    oci_identity_tag_namespace.resident, 
    oci_identity_tag.resident, 
    oci_identity_tag_default.resident
  ]
  compartment_id = oci_identity_compartment.resident.id
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
  for_each       = oci_ons_notification_topic.resident
  topic_id       = each.value.id
  endpoint       = var.configuration.resident.notifications[each.value.name].endpoint
  protocol       = var.configuration.resident.notifications[each.value.name].protocol
}
// --- notification service --- //
