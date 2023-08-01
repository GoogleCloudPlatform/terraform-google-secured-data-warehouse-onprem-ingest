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

resource "google_storage_bucket_iam_member" "objectAdmin" {
  bucket = module.dataflow_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.dataflow_controller_service_account_email}"
}

resource "google_storage_bucket_iam_member" "objectCreator" {
  bucket = module.data_ingestion_bucket.bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.storage_writer_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "publisher" {
  project = var.data_ingestion_project_id
  topic   = module.data_ingestion_topic.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.pubsub_writer_service_account_email}"
}

resource "google_storage_bucket_iam_member" "objectViewer" {
  bucket = module.data_ingestion_bucket.bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.cloudfunction_controller_service_account_email}"
}
