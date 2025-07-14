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
  pubsub_resource_location = lower(var.pubsub_resource_location)
  location                 = lower(var.location)
  cmek_location            = local.location == "eu" ? "europe" : local.location
  projects_to_remove_owner = var.remove_owner_role ? local.projects_ids : {}

  projects_ids = {
    data_ingestion = var.data_ingestion_project_id
    governance     = var.data_governance_project_id
    data           = var.data_project_id
  }

  restricted_non_cmek_services = {
    data_ingestion = []
    governance     = []
    data           = ["bigquery.googleapis.com"]
  }
}

resource "google_project_iam_binding" "remove_owner_role" {
  for_each = local.projects_to_remove_owner

  project = each.value
  role    = "roles/owner"
  members = []
}

/**
* Data Governance project
*/
module "data_governance_sa" {
  source = "./modules/data-governance-sa"

  data_project_id            = var.data_project_id
  terraform_service_account  = var.terraform_service_account
  data_ingestion_project_id  = var.data_ingestion_project_id
  data_governance_project_id = var.data_governance_project_id
}

module "data_governance" {
  source = "./modules/data-governance"

  labels                                      = var.labels
  data_ingestion_project_number               = var.data_ingestion_project_number
  data_governance_project_id                  = var.data_governance_project_id
  data_project_number                         = var.data_project_number
  cmek_location                               = local.cmek_location
  cmek_keyring_name                           = var.cmek_keyring_name
  key_rotation_period_seconds                 = var.key_rotation_period_seconds
  delete_contents_on_destroy                  = var.delete_contents_on_destroy
  kms_key_protection_level                    = var.kms_key_protection_level
  data_ingestion_gcs_sa_account               = module.data_governance_sa.data_ingestion_gcs_sa_account
  data_ingestion_artifact_registry_sa_account = module.data_governance_sa.data_ingestion_artifact_registry_sa_account
  data_ingestion_eventarc_sa_account          = module.data_governance_sa.data_ingestion_eventarc_sa_account
  data_ingestion_pubsub_sa_account            = module.data_governance_sa.data_ingestion_pubsub_sa_account
  data_ingestion_dataflow_sa_account          = module.data_governance_sa.data_ingestion_dataflow_sa_account
  data_governance_bigquery_sa_account         = module.data_governance_sa.data_governance_bigquery_sa_account
  data_bq_encryption_service_sa_account       = module.data_governance_sa.data_bq_encryption_service_sa_account
  data_gcs_sa_account                         = module.data_governance_sa.data_gcs_sa_account
  data_bigquery_sa_account                    = module.data_governance_sa.data_bigquery_sa_account
  data_dataflow_sa_account                    = module.data_governance_sa.data_dataflow_sa_account
  bq_location                                 = local.location
  dlp_output_dataset                          = var.dlp_output_dataset
  dataset_default_table_expiration_ms         = var.dataset_default_table_expiration_ms

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

/**
* Data Ingestion project
*/
module "data_ingestion_sa" {
  source = "./modules/data-ingestion-sa"

  data_ingestion_project_id  = var.data_ingestion_project_id
  data_governance_project_id = var.data_governance_project_id
  enable_bigquery_read_roles = var.enable_bigquery_read_roles_in_data_ingestion

  service_account_users = {
    terraform_sa  = "serviceAccount:${var.terraform_service_account}"
    data_engineer = "group:${var.data_engineer_group}"
    data_analyst  = "group:${var.data_analyst_group}"
  }
}

module "data_ingestion" {
  source = "./modules/data-ingestion"

  labels                                         = var.labels
  bucket_name                                    = var.bucket_name
  bucket_class                                   = var.bucket_class
  bucket_lifecycle_rules                         = var.bucket_lifecycle_rules
  delete_contents_on_destroy                     = var.delete_contents_on_destroy
  data_ingestion_project_id                      = var.data_ingestion_project_id
  data_ingestion_project_number                  = var.data_ingestion_project_number
  pubsub_resource_location                       = local.pubsub_resource_location
  bucket_location                                = local.location
  data_ingestion_encryption_key                  = module.data_governance.cmek_data_ingestion_crypto_key
  dataflow_controller_service_account_email      = module.data_ingestion_sa.dataflow_controller_service_account_email
  storage_writer_service_account_email           = module.data_ingestion_sa.storage_writer_service_account_email
  pubsub_writer_service_account_email            = module.data_ingestion_sa.pubsub_writer_service_account_email
  cloudfunction_controller_service_account_email = module.data_ingestion_sa.cloudfunction_controller_service_account_email

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

/**
* Data project
*/
module "bigquery_data" {
  source = "./modules/data"

  project_id                                = var.data_project_id
  dataset_id                                = var.dataset_id
  dataset_name                              = var.dataset_name
  dataset_description                       = var.dataset_description
  labels                                    = var.labels
  location                                  = local.location
  bigquery_encryption_key                   = module.data_governance.cmek_data_bigquery_crypto_key
  dataflow_controller_service_account_email = module.data_ingestion_sa.dataflow_controller_service_account_email
  terraform_service_account                 = var.terraform_service_account
  delete_contents_on_destroy                = var.delete_contents_on_destroy
  dataset_default_table_expiration_ms       = var.dataset_default_table_expiration_ms

  access = [{
    role          = "roles/bigquery.dataOwner"
    user_by_email = module.data_ingestion_sa.cloudfunction_controller_service_account_email
  }]

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

module "postgresql_data" {
  source = "./modules/postgresql-data"

  count = var.postgresql != null ? 1 : 0

  project_id          = var.data_project_id
  region              = var.location
  tier                = var.postgresql.tier
  edition             = var.postgresql.edition
  deletion_protection = !var.delete_contents_on_destroy

  database_flags   = var.postgresql.database_flags
  database_version = var.postgresql.database_version

  maintenance_version     = var.postgresql.maintenance_version
  maintenance_window_day  = var.postgresql.maintenance_window_day
  maintenance_window_hour = var.postgresql.maintenance_window_hour

  encrypted_data_reader_group = var.encrypted_data_reader_group
  plaintext_reader_group      = var.plaintext_reader_group
}

/**
* Organization projects setup
*/
module "org_policies" {
  source   = "./modules/organization-policies"
  for_each = local.projects_ids

  project_id                     = each.value
  trusted_locations              = var.trusted_locations
  trusted_shared_vpc_subnetworks = var.trusted_shared_vpc_subnetworks
  domains_to_allow               = var.domains_to_allow
  restricted_non_cmek_services   = local.restricted_non_cmek_services[each.key]

  depends_on = [
    module.data_ingestion,
    module.bigquery_data
  ]
}
