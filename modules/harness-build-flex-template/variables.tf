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

variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
}

variable "flex_template_bucket_name" {
  description = "The name of the Google Storage Bucket used to save the Dataflow flex template created."
  type        = string
}

variable "cloudbuild_bucket_name" {
  description = "The name of the Google Storage Bucket used to save temporary files in Cloud Build builds."
  type        = string
}

variable "docker_repository_url" {
  description = "URL of the docker flex template artifact registry repository."
  type        = string
}

variable "service_account_email" {
  description = "Terraform service account email"
  type        = string
}

variable "pip_index_url" {
  description = "The URL of the Python Package Index repository to be used to load the Python third-party packages."
  type        = string
}
