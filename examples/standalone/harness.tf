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
  projects_ids = {
    data_ingestion = module.harness_projects.data_ingestion_project_id,
    governance     = module.harness_projects.data_governance_project_id,
    data           = module.harness_projects.data_project_id
  }

  key_rotation_period_seconds = "2592000s" #30 days
}

module "harness_projects" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/harness-projects"
  version = "~> 0.1"

  org_id                       = var.org_id
  labels                       = { environment = "dev" }
  folder_id                    = var.folder_id
  billing_account              = var.billing_account
  region                       = local.location
  data_ingestion_project_name  = var.data_ingestion_project_name
  data_governance_project_name = var.data_governance_project_name
  data_project_name            = var.data_project_name
  service_account_email        = var.terraform_service_account
  deletion_policy              = local.deletion_policy
}

module "harness_artifact_registry_project" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/harness-artifact-registry"
  version = "~> 0.1"

  org_id                = var.org_id
  folder_id             = var.folder_id
  project_name          = var.template_project_name
  billing_account       = var.billing_account
  location              = local.location
  service_account_email = var.terraform_service_account
  deletion_policy       = local.deletion_policy
}

module "upload_python_modules" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/harness-upload-python-modules"
  version = "~> 0.1"

  project_id             = module.harness_artifact_registry_project.project_id
  location               = local.location
  cloudbuild_bucket_name = module.harness_artifact_registry_project.cloudbuild_bucket_name
  service_account_email  = module.harness_artifact_registry_project.cloudbuild_builder_email
  python_repository_id   = module.harness_artifact_registry_project.python_flex_template_repository_id

  depends_on = [
    module.harness_artifact_registry_project
  ]
}

module "build_flex_template" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/harness-build-flex-template"
  version = "~> 0.1"

  project_id                = module.harness_artifact_registry_project.project_id
  docker_repository_url     = module.harness_artifact_registry_project.docker_flex_template_repository_url
  service_account_email     = module.harness_artifact_registry_project.cloudbuild_builder_email
  cloudbuild_bucket_name    = module.harness_artifact_registry_project.cloudbuild_bucket_name
  flex_template_bucket_name = module.harness_artifact_registry_project.flex_template_bucket_name
  pip_index_url             = module.harness_artifact_registry_project.pip_index_url

  depends_on = [
    module.harness_artifact_registry_project
  ]
}

module "centralized_logging" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/harness-logging"
  version = "~> 0.1"

  projects_ids                = local.projects_ids
  labels                      = { environment = "dev" }
  logging_project_id          = module.harness_projects.data_governance_project_id
  kms_project_id              = module.harness_projects.data_governance_project_id
  bucket_name                 = "bkt-logging-${module.harness_projects.data_governance_project_id}"
  logging_location            = local.location
  delete_contents_on_destroy  = var.delete_contents_on_destroy
  key_rotation_period_seconds = local.key_rotation_period_seconds

  depends_on = [
    module.harness_projects
  ]
}

resource "time_sleep" "wait_60_seconds_harness" {
  create_duration = "60s"

  depends_on = [
    module.harness_projects,
    module.upload_python_modules,
    module.build_flex_template,
    module.centralized_logging
  ]
}

resource "google_project_iam_binding" "remove_owner_role" {
  for_each = local.projects_ids

  project = each.value
  role    = "roles/owner"
  members = []

  depends_on = [
    time_sleep.wait_60_seconds_harness
  ]
}
