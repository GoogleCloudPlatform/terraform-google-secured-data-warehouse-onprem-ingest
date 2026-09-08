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
  storage_sa             = var.data_ingestion_gcs_sa_account
  pubsub_sa              = var.data_ingestion_pubsub_sa_account
  dataflow_sa            = var.data_ingestion_dataflow_sa_account
  compute_sa             = "service-${var.data_ingestion_project_number}@compute-system.iam.gserviceaccount.com"
  eventarc_sa            = var.data_ingestion_eventarc_sa_account
  artifact_registry_sa   = var.data_ingestion_artifact_registry_sa_account
  data_storage_sa        = var.data_gcs_sa_account
  data_dataflow_sa       = var.data_dataflow_sa_account
  data_compute_sa        = "service-${var.data_project_number}@compute-system.iam.gserviceaccount.com"
  data_bigquery_sa       = var.data_bigquery_sa_account
  governance_bigquery_sa = var.data_governance_bigquery_sa_account

  data_ingestion_keyring_name = "${var.cmek_keyring_name}_${random_id.suffix.hex}"
  data_ingestion_key_name     = "data_ingestion_kms_key_${random_id.suffix.hex}"

  reidentification_key_name = "reidentification_kms_key_${random_id.suffix.hex}"
  data_bigquery_key_name    = "data_bigquery_kms_key_${random_id.suffix.hex}"
  gov_bigquery_key_name     = "gov_bigquery_kms_key_${random_id.suffix.hex}"

  data_ingestion_key_encrypters_decrypters = "serviceAccount:${local.storage_sa},serviceAccount:${local.pubsub_sa},serviceAccount:${local.dataflow_sa},serviceAccount:${local.compute_sa},serviceAccount:${local.artifact_registry_sa},serviceAccount:${local.eventarc_sa}"

  reidentification_key_encrypters_decrypters = "serviceAccount:${local.data_storage_sa},serviceAccount:${local.data_dataflow_sa},serviceAccount:${local.data_compute_sa}"
  data_bigquery_key_encrypters_decrypters    = "serviceAccount:${local.data_bigquery_sa},serviceAccount:${var.data_bq_encryption_service_sa_account}"
  gov_bigquery_key_encrypters_decrypters     = "serviceAccount:${local.governance_bigquery_sa}"


  keys = [
    local.data_ingestion_key_name,
    local.reidentification_key_name,
    local.data_bigquery_key_name,
    local.gov_bigquery_key_name
  ]

  encrypters = [
    local.data_ingestion_key_encrypters_decrypters,
    local.reidentification_key_encrypters_decrypters,
    local.data_bigquery_key_encrypters_decrypters,
    local.gov_bigquery_key_encrypters_decrypters
  ]

  decrypters = [
    local.data_ingestion_key_encrypters_decrypters,
    local.reidentification_key_encrypters_decrypters,
    local.data_bigquery_key_encrypters_decrypters,
    local.gov_bigquery_key_encrypters_decrypters
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}

module "cmek" {
  source  = "terraform-google-modules/kms/google"
  version = "4.1.2"

  project_id           = var.data_governance_project_id
  labels               = var.labels
  location             = var.cmek_location
  keyring              = local.data_ingestion_keyring_name
  key_rotation_period  = var.key_rotation_period_seconds
  prevent_destroy      = !var.delete_contents_on_destroy
  keys                 = local.keys
  key_protection_level = var.kms_key_protection_level
  set_encrypters_for   = local.keys
  set_decrypters_for   = local.keys
  encrypters           = local.encrypters
  decrypters           = local.decrypters
}

module "bigquery_dlp_output_data" {
  source  = "terraform-google-modules/bigquery/google"
  version = "10.2.1"

  project_id                  = var.data_governance_project_id
  dataset_id                  = var.dlp_output_dataset
  description                 = "Dataset to store the output from DLP job."
  dataset_name                = var.dlp_output_dataset
  location                    = var.bq_location
  encryption_key              = module.cmek.keys[local.gov_bigquery_key_name]
  delete_contents_on_destroy  = var.delete_contents_on_destroy
  default_table_expiration_ms = var.dataset_default_table_expiration_ms
}
