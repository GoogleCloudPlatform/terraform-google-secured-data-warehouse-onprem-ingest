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
* Data Ingestion project
*/
data "google_storage_project_service_account" "data_ingestion_gcs_account" {
  project = var.data_ingestion_project_id
}

resource "google_project_service_identity" "data_ingestion_artifact_registry_account" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service_identity" "data_ingestion_eventarc_account" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "eventarc.googleapis.com"
}

resource "google_project_service_identity" "data_ingestion_pubsub_sa" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "pubsub.googleapis.com"
}

resource "google_project_service_identity" "data_ingestion_dataflow_sa" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "dataflow.googleapis.com"
}

/**
* Data project
*/
module "get_bigquery_encryption_sa" {
  source = "../get-bq-encryption-sa"

  project_id                = var.data_project_id
  terraform_service_account = var.terraform_service_account
}

data "google_storage_project_service_account" "data_gcs_account" {
  project = var.data_project_id
}

data "google_bigquery_default_service_account" "data_bigquery_sa" {
  project = var.data_project_id
}

resource "google_project_service_identity" "data_dataflow_sa" {
  provider = google-beta

  project = var.data_project_id
  service = "dataflow.googleapis.com"
}

/**
* Data Governance project
*/
data "google_bigquery_default_service_account" "data_governance_bigquery_sa" {
  project = var.data_governance_project_id
}
