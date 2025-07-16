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

resource "random_string" "common" {
  length  = 10
  special = false
  upper   = false
}

module "example" {
  source                           = "../../../examples/standalone"
  org_id                           = var.org_id
  folder_id                        = var.folder_id
  billing_account                  = var.billing_account
  access_context_manager_policy_id = var.access_context_manager_policy_id
  terraform_service_account        = var.terraform_service_account
  perimeter_additional_members     = []
  delete_contents_on_destroy       = true
  template_project_name            = "harness-${random_string.common.result}"
  data_ingestion_project_name      = "ing-${random_string.common.result}"
  data_governance_project_name     = "gov-${random_string.common.result}"
  data_project_name                = "data-${random_string.common.result}"
  data_engineer_group              = var.group_email
  data_analyst_group               = var.group_email
  security_analyst_group           = var.group_email
  network_administrator_group      = var.group_email
  security_administrator_group     = var.group_email
  encrypted_data_reader_group      = var.group_email
  plaintext_reader_group           = var.group_email
  build_project_number             = var.build_project_number
}
