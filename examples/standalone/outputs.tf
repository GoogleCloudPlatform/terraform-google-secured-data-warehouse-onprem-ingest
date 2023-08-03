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

output "cmek_data_bigquery_crypto_key" {
  description = "The Customer Managed Crypto Key for the BigQuery service."
  value       = module.secured_data_warehouse_onprem_ingest.cmek_data_bigquery_crypto_key
}

output "cmek_data_ingestion_crypto_key" {
  description = "The Customer Managed Crypto Key for the data ingestion crypto boundary."
  value       = module.secured_data_warehouse_onprem_ingest.cmek_data_ingestion_crypto_key
}

output "cmek_keyring_name" {
  description = "The Keyring name for the KMS Customer Managed Encryption Keys."
  value       = module.secured_data_warehouse_onprem_ingest.cmek_keyring_name
}

output "centralized_logging_bucket_name" {
  description = "The name of the bucket created for storage logging."
  value       = module.centralized_logging.logging_bucket_name
}

output "dataflow_controller_service_account_email" {
  description = "The Dataflow controller service account email. Required to deploy Dataflow jobs. See https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account."
  value       = module.secured_data_warehouse_onprem_ingest.dataflow_controller_service_account_email
}

output "data_ingestion_bucket_name" {
  description = "The name of the bucket created for the data ingestion pipeline."
  value       = module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name
}

output "data_ingestion_dataflow_bucket_name" {
  description = "The name of the staging bucket created for dataflow in the data ingestion pipeline."
  value       = module.secured_data_warehouse_onprem_ingest.data_ingestion_dataflow_bucket_name
}

output "data_project_id" {
  description = "The ID of the project created for datasets and tables."
  value       = module.harness_projects.data_project_id
}

output "data_governance_project_id" {
  description = "The ID of the project created for data governance."
  value       = module.harness_projects.data_governance_project_id
}

output "data_ingestion_project_id" {
  description = "The ID of the project created for the data ingestion pipeline."
  value       = module.harness_projects.data_ingestion_project_id
}

output "template_project_id" {
  description = "The id of the flex template created."
  value       = module.harness_artifact_registry_project.project_id
}

output "data_ingestion_topic_name" {
  description = "The topic created for data ingestion pipeline."
  value       = module.secured_data_warehouse_onprem_ingest.data_ingestion_topic_name
}

output "pubsub_writer_service_account_email" {
  description = "The PubSub writer service account email. Should be used to write data to the PubSub topics the data ingestion pipeline reads from."
  value       = module.secured_data_warehouse_onprem_ingest.pubsub_writer_service_account_email
}

output "storage_writer_service_account_email" {
  description = "The Storage writer service account email. Should be used to write data to the buckets the data ingestion pipeline reads from."
  value       = module.secured_data_warehouse_onprem_ingest.storage_writer_service_account_email
}

output "data_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = module.secured_data_warehouse_onprem_ingest.data_service_perimeter_name
}

output "data_governance_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = module.secured_data_warehouse_onprem_ingest.data_governance_service_perimeter_name
}

output "data_ingestion_service_perimeter_name" {
  description = "Access context manager service perimeter name."
  value       = module.secured_data_warehouse_onprem_ingest.data_ingestion_service_perimeter_name
}

output "data_ingestion_network_name" {
  description = "The name of the data ingestion VPC being created."
  value       = module.harness_projects.data_ingestion_network_name
}

output "data_ingestion_network_self_link" {
  description = "The URI of the data ingestion VPC being created."
  value       = module.harness_projects.data_ingestion_network_self_link
}

output "data_ingestion_subnets_self_link" {
  description = "The self-links of data ingestion subnets being created."
  value       = module.harness_projects.data_ingestion_subnets_self_link
}
