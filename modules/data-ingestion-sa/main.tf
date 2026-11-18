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
  default_data_ingestion_project_roles = [
    "roles/pubsub.subscriber",
    "roles/pubsub.editor",
    "roles/storage.objectViewer",
    "roles/dataflow.worker",
    "roles/dataflow.developer"
  ]

  bigquery_read_roles = [
    "roles/bigquery.jobUser",
    "roles/bigquery.dataEditor",
    "roles/serviceusage.serviceUsageConsumer"
  ]

  additional_project_roles = var.enable_bigquery_read_roles ? local.bigquery_read_roles : []

  data_ingestion_project_roles = distinct(concat(local.additional_project_roles, local.default_data_ingestion_project_roles))

  governance_project_roles = [
    "roles/dlp.user",
    "roles/dlp.inspectTemplatesReader",
    "roles/dlp.deidentifyTemplatesReader"
  ]

  cloudfunction_data_project_roles = [
    "roles/artifactregistry.writer",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/eventarc.eventReceiver",
    "roles/logging.logWriter",
  ]
}

//Dataflow controller service account
module "dataflow_controller_service_account" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "4.7.0"

  project_id   = var.data_ingestion_project_id
  names        = ["sa-dataflow-controller"]
  display_name = "Cloud Dataflow controller service account"
}

resource "google_service_account_iam_member" "dataflow_controller_service_account_user" {
  for_each = var.service_account_users

  service_account_id = module.dataflow_controller_service_account.service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

resource "google_project_iam_member" "ingestion" {
  for_each = toset(local.data_ingestion_project_roles)

  project = var.data_ingestion_project_id
  role    = each.value
  member  = "serviceAccount:${module.dataflow_controller_service_account.email}"
}

resource "google_project_iam_member" "governance" {
  for_each = toset(local.governance_project_roles)

  project = var.data_governance_project_id
  role    = each.value
  member  = "serviceAccount:${module.dataflow_controller_service_account.email}"
}

//service account for storage
resource "google_service_account" "storage_writer_service_account" {
  project      = var.data_ingestion_project_id
  account_id   = "sa-storage-writer"
  display_name = "Cloud Storage data writer service account"
}

//service account for Pub/sub
resource "google_service_account" "pubsub_writer_service_account" {
  project      = var.data_ingestion_project_id
  account_id   = "sa-pubsub-writer"
  display_name = "Cloud PubSub data writer service account"
}

// Cloud Function service account
module "cloudfunction_controller_service_account" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "4.7"

  project_id   = var.data_ingestion_project_id
  names        = ["sa-cloudfunction-controller"]
  display_name = "Cloud Function controller service account"
}

resource "google_project_iam_member" "cloudfunction" {
  for_each = toset(local.cloudfunction_data_project_roles)

  project = var.data_ingestion_project_id
  role    = each.value
  member  = "serviceAccount:${module.cloudfunction_controller_service_account.email}"
}

resource "google_service_account_iam_member" "cloud_function_sa_service_account_user" {
  for_each = var.service_account_users

  service_account_id = module.cloudfunction_controller_service_account.service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}
