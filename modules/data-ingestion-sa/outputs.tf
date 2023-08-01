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

output "dataflow_controller_service_account_email" {
  description = "The Dataflow controller service account email. See https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account."
  value       = module.dataflow_controller_service_account.email
}

output "storage_writer_service_account_email" {
  description = "The Storage writer service account email. Should be used to write data to the buckets the data ingestion pipeline reads from."
  value       = google_service_account.storage_writer_service_account.email
}

output "pubsub_writer_service_account_email" {
  description = "The PubSub writer service account email. Should be used to write data to the PubSub topics the data ingestion pipeline reads from."
  value       = google_service_account.pubsub_writer_service_account.email
}

output "cloudfunction_controller_service_account_email" {
  description = "The Cloud Function controller service account email."
  value       = module.cloudfunction_controller_service_account.email
}
