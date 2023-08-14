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

locals {
  data_engineer_group_data_ingestion_project_roles = [
    "roles/logging.viewer",
    "roles/dataflow.admin",
    "roles/cloudkms.viewer",
    "roles/cloudbuild.builds.editor",
    "roles/compute.networkUser",
    "roles/composer.user"
  ]

  data_engineer_group_data_project_roles = [
    "roles/logging.viewer",
    "roles/cloudkms.viewer",
    "roles/cloudbuild.builds.editor",
    "roles/compute.networkUser",
    "roles/dataflow.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/dlp.admin"
  ]

  data_analyst_group_data_ingestion_project_roles = [
    "roles/logging.viewer",
    "roles/dataflow.viewer",
    "roles/dataflow.developer"
  ]

  data_analyst_group_data_project_roles = [
    "roles/logging.viewer",
    "roles/dataflow.viewer",
    "roles/dataflow.developer",
    "roles/dlp.admin",
    "roles/bigquery.dataViewer",
    "roles/bigquery.jobUser",
    "roles/bigquery.user",
  ]

  security_analyst_group_org_roles = [
    "roles/logging.viewer",
    "roles/accesscontextmanager.policyReader",
    "roles/cloudkms.viewer",
    "roles/datacatalog.viewer",
    "roles/networkmanagement.viewer",
    "roles/orgpolicy.policyViewer",
    "roles/securitycenter.adminViewer",
    "roles/securitycenter.findingsEditor",
    "roles/securitycenter.findingsMuteSetter",
    "roles/securitycenter.findingsStateSetter",
    "roles/securitycenter.findingsBulkMuteEditor"
  ]

  network_administrator_group_org_roles = [
    "roles/logging.viewer",
    "roles/compute.networkAdmin"
  ]

  security_administrator_group_org_roles = [
    "roles/cloudkms.admin",
    "roles/datacatalog.admin",
    "roles/dlp.admin",
    "roles/accesscontextmanager.policyAdmin",
    "roles/orgpolicy.policyAdmin",
    "roles/logging.admin",
    "roles/cloudasset.viewer",
    "roles/compute.securityAdmin",
    "roles/iam.securityAdmin"
  ]

  plaintext_reader_group_data_project_bigquery_roles = [
    "roles/bigquery.dataViewer"
  ]

  encrypted_data_reader_group_data_project_bigquery_roles = [
    "roles/bigquery.user"
  ]

  plaintext_reader_group_data_project_roles = [
    "roles/cloudkms.viewer",
    "roles/bigquery.jobUser",
    "roles/bigquery.user"
  ]

  encrypted_data_reader_group_data_project_roles = [
    "roles/bigquery.jobUser"
  ]

}

resource "google_project_iam_member" "data-engineer-group-ingestion" {
  for_each = toset(local.data_engineer_group_data_ingestion_project_roles)

  project = var.data_ingestion_project_id
  role    = each.value
  member  = "group:${var.data_engineer_group}"
}

resource "google_project_iam_member" "data-engineer-group" {
  for_each = toset(local.data_engineer_group_data_project_roles)

  project = var.data_project_id
  role    = each.value
  member  = "group:${var.data_engineer_group}"
}

resource "google_project_iam_member" "data-analyst-group-ingestion" {
  for_each = toset(local.data_analyst_group_data_ingestion_project_roles)

  project = var.data_ingestion_project_id
  role    = each.value
  member  = "group:${var.data_analyst_group}"
}

resource "google_project_iam_member" "data-analyst-group" {
  for_each = toset(local.data_analyst_group_data_project_roles)

  project = var.data_project_id
  role    = each.value
  member  = "group:${var.data_analyst_group}"
}

resource "google_organization_iam_member" "security-analyst-group" {
  for_each = toset(local.security_analyst_group_org_roles)

  org_id = var.org_id
  role   = each.value
  member = "group:${var.security_analyst_group}"
}

resource "google_organization_iam_member" "network-administrator-group" {
  for_each = toset(local.network_administrator_group_org_roles)

  org_id = var.org_id
  role   = each.value
  member = "group:${var.network_administrator_group}"
}

resource "google_organization_iam_member" "security-administrator-group" {
  for_each = toset(local.security_administrator_group_org_roles)

  org_id = var.org_id
  role   = each.value
  member = "group:${var.security_administrator_group}"
}

resource "google_project_iam_member" "plaintext_reader_group" {
  for_each = toset(local.plaintext_reader_group_data_project_roles)

  project = var.data_project_id
  role    = each.value
  member  = "group:${var.plaintext_reader_group}"
}

resource "google_project_iam_member" "encrypted_data_reader_group" {
  for_each = toset(local.encrypted_data_reader_group_data_project_roles)

  project = var.data_project_id
  role    = each.value
  member  = "group:${var.encrypted_data_reader_group}"
}

resource "google_bigquery_dataset_iam_member" "encrypted_data_reader_group" {
  for_each = toset(local.encrypted_data_reader_group_data_project_bigquery_roles)

  project    = var.data_project_id
  dataset_id = var.dataset_id
  role       = each.value
  member     = "group:${var.encrypted_data_reader_group}"

  depends_on = [
    module.bigquery_data
  ]
}

resource "google_bigquery_dataset_iam_member" "plaintext_data_reader_group" {
  for_each = toset(local.plaintext_reader_group_data_project_bigquery_roles)

  project    = var.data_project_id
  dataset_id = var.dataset_id
  role       = each.value
  member     = "group:${var.plaintext_reader_group}"

  depends_on = [
    module.bigquery_data
  ]
}
