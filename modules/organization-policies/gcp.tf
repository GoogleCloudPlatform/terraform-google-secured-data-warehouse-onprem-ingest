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
  locations = [for l in var.trusted_locations : "in:${l}"]
}

module "location_restriction_policy" {
  source  = "terraform-google-modules/org-policy/google"
  version = "7.2.0"

  policy_for        = "project"
  project_id        = var.project_id
  constraint        = "constraints/gcp.resourceLocations"
  policy_type       = "list"
  allow             = local.locations[*]
  allow_list_length = 1
}

module "org_domain_restricted_sharing" {
  source  = "terraform-google-modules/org-policy/google//modules/domain_restricted_sharing"
  version = "7.2.0"
  count   = length(var.domains_to_allow) == 0 ? 0 : 1

  policy_for       = "project"
  project_id       = var.project_id
  domains_to_allow = var.domains_to_allow

}

module "restricted_non_cmek_services" {
  source  = "terraform-google-modules/org-policy/google"
  version = "7.2.0"
  count   = length(var.restricted_non_cmek_services) > 0 ? 1 : 0

  policy_for       = "project"
  project_id       = var.project_id
  constraint       = "constraints/gcp.restrictNonCmekServices"
  policy_type      = "list"
  deny             = var.restricted_non_cmek_services
  deny_list_length = 1
}
