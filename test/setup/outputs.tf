/**
 * Copyright 2019 Google LLC
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

output "sa_key" {
  value     = google_service_account_key.int_test.private_key
  sensitive = true
}

output "terraform_service_account" {
  value = google_service_account.int_test.email
}

output "org_project_creators" {
  value = ["serviceAccount:${google_service_account.int_test.email}"]
}

output "org_id" {
  value = var.org_id
}

output "folder_id" {
  value = google_folder.int_test.id
}

output "billing_account" {
  value = var.billing_account
}

output "group_email" {
  value = "test-gcp-qa@test.blueprints.joonix.net"
}

output "access_context_manager_policy_id" {
  value = data.google_access_context_manager_access_policy.main.name
}
