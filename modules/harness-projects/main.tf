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
  data_ingestion_project_name  = var.data_ingestion_project_name != "" ? var.data_ingestion_project_name : "sdw-data-ing-${random_id.project_id_suffix.hex}"
  data_governance_project_name = var.data_governance_project_name != "" ? var.data_governance_project_name : "sdw-data-gov-${random_id.project_id_suffix.hex}"
  data_project_name            = var.data_project_name != "" ? var.data_project_name : "sdw-data-${random_id.project_id_suffix.hex}"
}

resource "random_id" "project_id_suffix" {
  byte_length = 3
}

module "data_ingestion_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.2"

  name                    = local.data_ingestion_project_name
  random_project_id       = "true"
  org_id                  = var.org_id
  labels                  = var.labels
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
  deletion_policy         = var.deletion_policy

  activate_apis = [
    "vpcaccess.googleapis.com",
    "container.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "datacatalog.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "dataflow.googleapis.com",
    "dlp.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com"
  ]
}

module "data_governance_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.2"

  name                    = local.data_governance_project_name
  random_project_id       = "true"
  org_id                  = var.org_id
  labels                  = var.labels
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
  deletion_policy         = var.deletion_policy

  activate_apis = [
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "datacatalog.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "dlp.googleapis.com",
    "secretmanager.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquery.googleapis.com"
  ]
}

resource "google_project_service_identity" "data_governance_service_agents" {
  provider = google-beta

  for_each = toset(
    [
      "cloudkms.googleapis.com",
      "logging.googleapis.com",
      "storage.googleapis.com",
    ]
  )
  project = module.data_governance_project.project_id
  service = each.key
}

module "data_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.2"

  name                    = local.data_project_name
  random_project_id       = "true"
  org_id                  = var.org_id
  labels                  = var.labels
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
  deletion_policy         = var.deletion_policy

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "bigquery.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "dataflow.googleapis.com",
    "dlp.googleapis.com",
    "datacatalog.googleapis.com",
    "dns.googleapis.com",
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
}
