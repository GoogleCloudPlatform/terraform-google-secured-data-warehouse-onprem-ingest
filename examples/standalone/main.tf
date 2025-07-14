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
  location        = "us-east4"
  dataset_id      = "data_dataset"
  deletion_policy = var.delete_contents_on_destroy ? "DELETE" : "PREVENT"
}

resource "time_sleep" "wait_harness_projects_creation" {
  depends_on = [
    module.harness_projects,
  ]

  create_duration = "900s"
}

module "secured_data_warehouse_onprem_ingest" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google"
  version = "~> 0.1"

  org_id                           = var.org_id
  labels                           = { environment = "dev" }
  data_governance_project_id       = module.harness_projects.data_governance_project_id
  data_governance_project_number   = module.harness_projects.data_governance_project_number
  data_project_id                  = module.harness_projects.data_project_id
  data_project_number              = module.harness_projects.data_project_number
  data_ingestion_project_id        = module.harness_projects.data_ingestion_project_id
  data_ingestion_project_number    = module.harness_projects.data_ingestion_project_number
  sdx_project_number               = module.harness_artifact_registry_project.sdx_project_number
  terraform_service_account        = var.terraform_service_account
  access_context_manager_policy_id = var.access_context_manager_policy_id
  bucket_name                      = "standalone-data-ing"
  pubsub_resource_location         = local.location
  location                         = local.location
  trusted_locations                = ["us-locations"]
  dataset_id                       = local.dataset_id
  cmek_keyring_name                = "standalone-data-ing"
  delete_contents_on_destroy       = var.delete_contents_on_destroy
  perimeter_additional_members     = var.perimeter_additional_members
  data_engineer_group              = var.data_engineer_group
  data_analyst_group               = var.data_analyst_group
  security_analyst_group           = var.security_analyst_group
  network_administrator_group      = var.network_administrator_group
  security_administrator_group     = var.security_administrator_group
  encrypted_data_reader_group      = var.encrypted_data_reader_group
  plaintext_reader_group           = var.plaintext_reader_group
  access_level_ip_subnetworks      = var.access_level_ip_subnetworks

  // Set the enable_bigquery_read_roles_in_data_ingestion to true, it will grant to the dataflow controller
  // service account created in the data ingestion project the necessary roles to read from a bigquery table.
  enable_bigquery_read_roles_in_data_ingestion = true

  postgresql = {
    database_version            = "17"
    deletion_protection_enabled = !var.delete_contents_on_destroy
    tier                        = "db-f1-micro"
    edition                     = "ENTERPRISE"
  }

  depends_on = [
    google_project_iam_binding.remove_owner_role,
    time_sleep.wait_60_seconds_harness,
  ]
}
