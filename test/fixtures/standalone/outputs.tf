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

output "data_ingestion_bucket_name" {
  description = "The name of the bucket created for the data ingestion pipeline."
  value       = module.example.data_ingestion_bucket_name
}

output "data_ingestion_dataflow_bucket_name" {
  description = "The name of the bucket created for dataflow in the data ingestion pipeline."
  value       = module.example.data_ingestion_dataflow_bucket_name
}

output "centralized_logging_bucket_name" {
  description = "The name of the bucket created for storage logging."
  value       = module.example.centralized_logging_bucket_name
}

output "data_project_id" {
  description = "The ID of the project created for datasets and tables."
  value       = module.example.data_project_id
}

output "data_governance_project_id" {
  description = "The ID of the project created for data governance."
  value       = module.example.data_governance_project_id
}

output "data_ingestion_project_id" {
  description = "The ID of the project created for the data ingstion pipeline."
  value       = module.example.data_ingestion_project_id
}

output "template_project_id" {
  description = "The id of the flex template created."
  value       = module.example.template_project_id
}

output "data_ingestion_topic_name" {
  description = "The topic created for data ingestion pipeline."
  value       = module.example.data_ingestion_topic_name
}

output "cmek_data_bigquery_crypto_key" {
  description = "The Customer Managed Crypto Key for the BigQuery service."
  value       = module.example.cmek_data_bigquery_crypto_key
}

output "cmek_data_ingestion_crypto_key" {
  description = "The Customer Managed Crypto Key for the data ingestion crypto boundary."
  value       = module.example.cmek_data_ingestion_crypto_key
}

output "cmek_keyring_name" {
  description = "The Keyring name for the KMS Customer Managed Encryption Keys."
  value       = module.example.cmek_keyring_name
}

output "terraform_service_account" {
  description = "Service account created by Setup."
  value       = var.terraform_service_account
}



