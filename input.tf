# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "account" {
  type = object({
    tenancy_id     = string,
    class          = number,
  })
  description = "Account parameter"
}

variable "options" {
  type = object({
    enable_delete = bool,
    parent_id     = string,
    user_id       = string
  })
  description = "Input for database module"
}

variable "configuration" {
  type = object({
    resident = any
  })
  description = "Service configuration"
}