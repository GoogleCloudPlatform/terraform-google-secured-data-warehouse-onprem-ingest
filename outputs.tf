/**
 * Copyright 2023 Google LLC
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

/**
* IAM outputs
*/
output "dataflow_controller_service_account_email" {
  description = "The Dataflow controller service account email. Required to deploy Dataflow jobs. See https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account."
  value       = module.data_ingestion_sa.dataflow_controller_service_account_email

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "cloudfunction_controller_service_account_email" {
  description = "The Cloud Function controller service account email."
  value       = module.data_ingestion_sa.cloudfunction_controller_service_account_email

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "storage_writer_service_account_email" {
  description = "The Storage writer service account email. Should be used to write data to the buckets the data ingestion pipeline reads from."
  value       = module.data_ingestion_sa.storage_writer_service_account_email
}

output "pubsub_writer_service_account_email" {
  description = "The PubSub writer service account email. Should be used to write data to the PubSub topics the data ingestion pipeline reads from."
  value       = module.data_ingestion_sa.pubsub_writer_service_account_email
}

/**
* Cloud Storage outputs
*/
output "data_ingestion_bucket_name" {
  description = "The name of the bucket created for the data ingestion pipeline."
  value       = module.data_ingestion.data_ingestion_bucket_name

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "data_ingestion_dataflow_bucket_name" {
  description = "The name of the staging bucket created for dataflow in the data ingestion pipeline."
  value       = module.data_ingestion.data_ingestion_dataflow_bucket_name

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "data_ingestion_cloudfunction_bucket_name" {
  description = "The name of the bucket created for cloud function in the data ingestion pipeline."
  value       = module.data_ingestion.data_ingestion_cloudfunction_bucket_name

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

/**
* Cloud Pub/Sub outputs
*/
output "data_ingestion_topic_name" {
  description = "The topic created for data ingestion pipeline."
  value       = module.data_ingestion.data_ingestion_topic_name

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

/**
* KMS outputs
*/
output "cmek_keyring_name" {
  description = "The Keyring name for the KMS Customer Managed Encryption Keys."
  value       = module.data_governance.cmek_keyring_name

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "cmek_data_ingestion_crypto_key" {
  description = "The Customer Managed Crypto Key for the data ingestion crypto boundary."
  value       = module.data_governance.cmek_data_ingestion_crypto_key

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "cmek_reidentification_crypto_key" {
  description = "The Customer Managed Crypto Key for the crypto boundary."
  value       = module.data_governance.cmek_reidentification_crypto_key

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

output "cmek_data_bigquery_crypto_key" {
  description = "The Customer Managed Crypto Key for the BigQuery service."
  value       = module.data_governance.cmek_data_bigquery_crypto_key

  depends_on = [
    time_sleep.wait_for_bridge_propagation
  ]
}

/**
* BigQuery outputs
*/
output "dataset" {
  description = "The BigQuery Dataset for the Data project."
  value       = module.bigquery_data.bigquery_dataset
}

output "dataset_id" {
  description = "The ID of the dataset created for the Data project."
  value       = module.bigquery_data.bigquery_dataset.dataset_id
}

output "dlp_output_dataset" {
  description = "The Dataset ID for DLP output data."
  value       = module.data_governance.dlp_output_dataset
}

/**
* VPC-SC outputs
*/
output "data_ingestion_access_level_name" {
  description = "Access context manager access level name."
  value       = var.data_ingestion_perimeter == "" ? module.data_ingestion_vpc_sc[0].access_level_name : ""
}

output "data_ingestion_service_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = var.data_ingestion_perimeter == "" ? module.data_ingestion_vpc_sc[0].service_perimeter_name : ""
}

output "data_governance_access_level_name" {
  description = "Access context manager access level name."
  value       = var.data_governance_perimeter == "" ? module.data_governance_vpc_sc[0].access_level_name : ""
}

output "data_governance_service_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = var.data_governance_perimeter == "" ? module.data_governance_vpc_sc[0].service_perimeter_name : ""
}

output "data_access_level_name" {
  description = "Access context manager access level name."
  value       = var.data_perimeter == "" ? module.data_vpc_sc[0].access_level_name : ""
}

output "data_service_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = var.data_perimeter == "" ? module.data_vpc_sc[0].service_perimeter_name : ""
}
