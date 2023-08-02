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

variable "data_ingestion_project_number" {
  description = "The project number of the project in which the data ingestion resources will be created."
  type        = string
}

variable "data_governance_project_id" {
  description = "The ID of the project in which the data governance resources will be created."
  type        = string
}

variable "data_project_number" {
  description = "The project number of the project in which the datasets and tables will be created."
  type        = string
}

variable "labels" {
  description = "(Optional) Labels attached to Data Warehouse resources."
  type        = map(string)
  default     = {}
}

variable "cmek_location" {
  description = "The location for the KMS Customer Managed Encryption Keys."
  type        = string
}

variable "cmek_keyring_name" {
  description = "The Keyring name for the KMS Customer Managed Encryption Keys."
  type        = string
}

variable "delete_contents_on_destroy" {
  description = "(Optional) If set to true, delete all the tables in the dataset when destroying the resource; otherwise, destroying the resource will fail if tables are present."
  type        = bool
  default     = false
}

variable "key_rotation_period_seconds" {
  description = "Rotation period for keys. The default value is 30 days."
  type        = string
  default     = "2592000s"
}

variable "kms_key_protection_level" {
  description = "The protection level to use when creating a key. Possible values: [\"SOFTWARE\", \"HSM\"]"
  type        = string
  default     = "HSM"
}

variable "dlp_output_dataset" {
  description = "Dataset ID for the DLP outputs."
  type        = string
}

variable "bq_location" {
  description = "Default region to create resources where applicable."
  type        = string
}

variable "dataset_default_table_expiration_ms" {
  description = "TTL of tables using the dataset in MS. The default value is null."
  type        = number
  default     = null
}

variable "data_ingestion_gcs_sa_account" {
  description = "Automatic Google Cloud Storage service account email for the Data Ingestion project."
  type        = string
}

variable "data_ingestion_artifact_registry_sa_account" {
  description = "Artifact Registry service agent service account email for the Data Ingestion project."
  type        = string
}

variable "data_ingestion_eventarc_sa_account" {
  description = "Eventarc service agent service account email for the Data Ingestion project."
  type        = string
}

variable "data_ingestion_pubsub_sa_account" {
  description = "Pub/Sub service agent service account email for the Data Ingestion project."
  type        = string
}

variable "data_ingestion_dataflow_sa_account" {
  description = "Dataflow service agent service account email for the Data Ingestion project."
  type        = string
}

variable "data_governance_bigquery_sa_account" {
  description = "Unique BigQuery service account email for the Data Governance project."
  type        = string
}

variable "data_bq_encryption_service_sa_account" {
  description = "The email of the service account used for interactions with Google Cloud KMS for the Data project."
  type        = string
}

variable "data_gcs_sa_account" {
  description = "Automatic Google Cloud Storage service account email for the Data project."
  type        = string
}

variable "data_bigquery_sa_account" {
  description = "Unique BigQuery service account email for the Data project."
  type        = string
}

variable "data_dataflow_sa_account" {
  description = "Dataflow service agent service account email for the Data project."
  type        = string
}
