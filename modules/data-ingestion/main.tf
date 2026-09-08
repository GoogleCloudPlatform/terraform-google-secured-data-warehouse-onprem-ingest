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

resource "random_id" "suffix" {
  byte_length = 4
}

//storage data ingestion bucket
module "data_ingestion_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "12.3.0"

  project_id      = var.data_ingestion_project_id
  labels          = var.labels
  name            = "bkt-${var.data_ingestion_project_id}-${var.bucket_name}-${random_id.suffix.hex}"
  location        = var.bucket_location
  storage_class   = var.bucket_class
  lifecycle_rules = var.bucket_lifecycle_rules
  force_destroy   = var.delete_contents_on_destroy

  encryption = {
    default_kms_key_name = var.data_ingestion_encryption_key
  }
}

module "dataflow_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "12.3.0"

  project_id    = var.data_ingestion_project_id
  labels        = var.labels
  name          = "bkt-${var.data_ingestion_project_id}-tmp-dataflow-${random_id.suffix.hex}"
  location      = var.bucket_location
  storage_class = "STANDARD"
  force_destroy = var.delete_contents_on_destroy


  encryption = {
    default_kms_key_name = var.data_ingestion_encryption_key
  }
}

module "cloudfunction_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 12.0"

  project_id    = var.data_ingestion_project_id
  labels        = var.labels
  name          = "gcf-v2-sources-${var.data_ingestion_project_number}-${var.bucket_location}"
  location      = var.bucket_location
  storage_class = "REGIONAL"
  force_destroy = var.delete_contents_on_destroy


  encryption = {
    default_kms_key_name = var.data_ingestion_encryption_key
  }
}

resource "google_storage_bucket_iam_member" "cloudfunction_bucket" {
  bucket = module.cloudfunction_bucket.bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.cloudfunction_controller_service_account_email}"
}

//pub/sub data ingestion topic
module "data_ingestion_topic" {
  source  = "terraform-google-modules/pubsub/google"
  version = "8.0"

  project_id             = var.data_ingestion_project_id
  topic_labels           = var.labels
  topic                  = "tpc-data-ingestion-${random_id.suffix.hex}"
  topic_kms_key_name     = var.data_ingestion_encryption_key
  message_storage_policy = { allowed_persistence_regions : [var.pubsub_resource_location] }
}
