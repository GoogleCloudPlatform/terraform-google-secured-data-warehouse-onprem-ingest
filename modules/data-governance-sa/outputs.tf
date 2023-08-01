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

output "data_ingestion_gcs_sa_account" {
  description = "Automatic Google Cloud Storage service account email for the Data Ingestion project."
  value       = data.google_storage_project_service_account.data_ingestion_gcs_account.email_address
}

output "data_ingestion_artifact_registry_sa_account" {
  description = "Artifact Registry service agent service account email for the Data Ingestion project."
  value       = google_project_service_identity.data_ingestion_artifact_registry_account.email
}

output "data_ingestion_eventarc_sa_account" {
  description = "Eventarc service agent service account email for the Data Ingestion project."
  value       = google_project_service_identity.data_ingestion_eventarc_account.email
}

output "data_ingestion_pubsub_sa_account" {
  description = "Pub/Sub service agent service account email for the Data Ingestion project."
  value       = google_project_service_identity.data_ingestion_pubsub_sa.email
}

output "data_ingestion_dataflow_sa_account" {
  description = "Dataflow service agent service account email for the Data Ingestion project."
  value       = google_project_service_identity.data_ingestion_dataflow_sa.email
}

output "data_governance_bigquery_sa_account" {
  description = "Unique BigQuery service account email for the Data Governance project."
  value       = data.google_bigquery_default_service_account.data_governance_bigquery_sa.email
}

output "data_bq_encryption_service_sa_account" {
  description = "The email of the service account used for interactions with Google Cloud KMS for the Data project."
  value       = module.get_bigquery_encryption_sa.bq_encryption_service_account
}

output "data_gcs_sa_account" {
  description = "Automatic Google Cloud Storage service account email for the Data project."
  value       = data.google_storage_project_service_account.data_gcs_account.email_address
}

output "data_bigquery_sa_account" {
  description = "Unique BigQuery service account email for the Data project."
  value       = data.google_bigquery_default_service_account.data_bigquery_sa.email
}

output "data_dataflow_sa_account" {
  description = "Dataflow service agent service account email for the Data project."
  value       = google_project_service_identity.data_dataflow_sa.email
}
