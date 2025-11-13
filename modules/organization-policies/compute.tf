/**
 * Copyright 2023-2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  boolean_compute_org_policies = toset([
    "compute.disableSerialPortLogging",
    "compute.skipDefaultNetworkCreation",
    "compute.requireOsLogin",
    "compute.disableSerialPortAccess",
    "storage.uniformBucketLevelAccess",
    "gcp.detailedAuditLoggingMode"
  ])
}

module "boolean_compute_org_policies" {
  source   = "terraform-google-modules/org-policy/google"
  version  = "7.2.0"
  for_each = local.boolean_compute_org_policies

  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "constraints/${each.value}"
  policy_type = "boolean"
  enforce     = true
}

module "protocol_forwarding_creation" {
  source  = "terraform-google-modules/org-policy/google"
  version = "7.2.0"

  policy_for        = "project"
  project_id        = var.project_id
  constraint        = "constraints/compute.restrictProtocolForwardingCreationForTypes"
  policy_type       = "list"
  allow             = ["is:INTERNAL"]
  allow_list_length = 1
}

module "restrict_shared_vpc_subnetworks_policy" {
  source  = "terraform-google-modules/org-policy/google"
  version = "7.2.0"
  count   = length(var.trusted_shared_vpc_subnetworks) > 0 ? 1 : 0

  policy_for        = "project"
  project_id        = var.project_id
  constraint        = "constraints/compute.restrictSharedVpcSubnetworks"
  policy_type       = "list"
  allow             = var.trusted_shared_vpc_subnetworks
  allow_list_length = length(var.trusted_shared_vpc_subnetworks)
}

module "vm_external_ip_access" {
  source  = "terraform-google-modules/org-policy/google"
  version = "7.2.0"

  policy_for  = "project"
  project_id  = var.project_id
  constraint  = "constraints/compute.vmExternalIpAccess"
  policy_type = "list"
  enforce     = true
}
