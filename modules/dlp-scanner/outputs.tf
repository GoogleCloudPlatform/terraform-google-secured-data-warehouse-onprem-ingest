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

output "dlp_job_trigger_name" {
  description = "The name of the DLP job trigger."
  value       = google_data_loss_prevention_job_trigger.dlp_job_trigger.name
}

output "dlp_job_trigger_id" {
  description = "The ID of the DLP job trigger."
  value       = google_data_loss_prevention_job_trigger.dlp_job_trigger.id
}
