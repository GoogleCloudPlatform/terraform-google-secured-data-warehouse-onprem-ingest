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
  int_proj_required_roles = [
    "roles/artifactregistry.admin",
    "roles/browser",
    "roles/cloudbuild.builds.editor",
    "roles/iam.serviceAccountCreator",
    "roles/iam.serviceAccountDeleter",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/storage.objectCreator",
  ]

  cloud_builder_required_roles = [
    "roles/artifactregistry.admin",
    "roles/browser",
    "roles/cloudbuild.builds.editor",
    "roles/logging.logWriter",
    "roles/storage.admin",
    "roles/storage.objectCreator",
  ]

  apis_to_enable = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com"
  ]

  project_name = var.project_name != "" ? var.project_name : "ext-harness-${random_id.project_id_suffix.hex}"
  project_id   = module.external_flex_template_project.project_id

  docker_repository_id  = "flex-templates"
  docker_repository_url = "${var.location}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.flex_templates.name}"

  python_repository_id  = "python-modules"
  python_repository_url = "${var.location}-python.pkg.dev/${local.project_id}/${google_artifact_registry_repository.python_modules.name}"
  pip_index_url         = "https://${var.location}-python.pkg.dev/${local.project_id}/${local.python_repository_id}/simple/"

}

resource "random_id" "project_id_suffix" {
  byte_length = 3
}

module "external_flex_template_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "18.2"

  name                    = local.project_name
  random_project_id       = "true"
  org_id                  = var.org_id
  folder_id               = var.folder_id
  billing_account         = var.billing_account
  default_service_account = "deprivilege"
  deletion_policy         = var.deletion_policy

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com"
  ]
}

# The name of this bucket is the name of the bucket that
# Cloud Build creates to host the source code if one is
# not provided with the flag `--gcs-source-staging-dir`.
# Creating the bucket beforehand is necessary because it
# is not possible to pass a `--gcs-source-staging-dir`
# flag to the gcloud dataflow flex-template build command
# used in the cloudbuild.yaml file.
resource "google_storage_bucket" "cloudbuild_bucket" {
  name     = "${local.project_id}_cloudbuild"
  location = var.location
  project  = local.project_id

  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [
    module.external_flex_template_project
  ]
}

resource "google_service_account" "cloud_builder" {
  account_id   = "cloud-builder"
  display_name = "Cloud Builder"
  project      = module.external_flex_template_project.project_id
}

resource "google_project_iam_member" "cloud_builder_roles" {
  for_each = toset(local.cloud_builder_required_roles)

  project = module.external_flex_template_project.project_id
  role    = each.value
  member  = google_service_account.cloud_builder.member
}

resource "google_project_iam_member" "int_permission_artifact_registry_test" {
  for_each = toset(local.int_proj_required_roles)

  project = module.external_flex_template_project.project_id
  role    = each.value
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_service" "apis_to_enable" {
  for_each = toset(local.apis_to_enable)

  project            = local.project_id
  service            = each.key
  disable_on_destroy = false

  depends_on = [
    google_project_iam_member.int_permission_artifact_registry_test
  ]
}

resource "google_project_service_identity" "cloudbuild_sa" {
  provider = google-beta

  project = local.project_id
  service = "cloudbuild.googleapis.com"

  depends_on = [
    google_project_service.apis_to_enable
  ]
}

resource "google_project_iam_member" "cloud_build_builder" {
  project = local.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"
}

resource "google_artifact_registry_repository" "flex_templates" {
  project       = local.project_id
  location      = var.location
  repository_id = local.docker_repository_id
  description   = "DataFlow Flex Templates"
  format        = "DOCKER"

  depends_on = [
    google_project_service.apis_to_enable
  ]
}

resource "google_artifact_registry_repository_iam_member" "docker_writer" {
  project    = local.project_id
  location   = var.location
  repository = local.docker_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"

  depends_on = [
    google_artifact_registry_repository.flex_templates
  ]
}

resource "google_artifact_registry_repository" "python_modules" {
  project       = local.project_id
  location      = var.location
  repository_id = local.python_repository_id
  description   = "Repository for Python modules for Dataflow flex templates"
  format        = "PYTHON"

  depends_on = [
    google_project_service.apis_to_enable
  ]
}

resource "google_artifact_registry_repository_iam_member" "python_writer" {
  project    = local.project_id
  location   = var.location
  repository = local.python_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"

  depends_on = [
    google_artifact_registry_repository.python_modules
  ]
}

resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_storage_bucket" "templates_bucket" {
  name     = "bkt-${local.project_id}-tpl-${random_id.suffix.hex}"
  location = var.location
  project  = local.project_id

  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [
    google_project_service.apis_to_enable
  ]
}

// It's necessary to use the wait_60_seconds to guarantee the infrastructure is fully built before removing the owner role.
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"

  depends_on = [
    google_storage_bucket.templates_bucket,
    google_artifact_registry_repository_iam_member.python_writer,
    google_artifact_registry_repository_iam_member.docker_writer,
    google_project_iam_member.cloud_build_builder
  ]
}

resource "google_project_iam_binding" "remove_owner_role_from_template" {
  project = local.project_id
  role    = "roles/owner"
  members = []

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

