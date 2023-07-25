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

variable "bq_project_id" {
  description = "The project that contains the BigQuery dataset to be scanned with Cloud Data Loss Prevention (DLP) API."
  type        = string
}

variable "bq_dataset_id" {
  description = "The BigQuery Dataset to scan."
  type        = string
}

variable "bq_table_id" {
  description = "The BigQuery Table to scan."
  type        = string
}

variable "terraform_service_account" {
  description = "The email address of the service account that will run the Terraform code."
  type        = string
}

variable "dlp_project_id" {
  description = "The project to host the DLP inspect template and job trigger."
  type        = string
}

variable "dlp_location" {
  description = "The location where DLP resources are going to be created."
  type        = string
}

variable "dlp_recurrence_period_duration" {
  description = "Recurrence period duration to be used on the DLP job trigger."
  type        = number
  default     = 86400

  validation {
    condition     = var.dlp_recurrence_period_duration >= 86400
    error_message = "Minimum value is 86400 seconds (1 day)."
  }

  validation {
    condition     = var.dlp_recurrence_period_duration <= 5184000
    error_message = "Maximum value is 5184000 seconds (60 days)."
  }
}

variable "dlp_output_dataset" {
  description = "The BigQuery Dataset ID for the DLP outputs."
  type        = string
}

variable "dlp_inspect_template_id" {
  description = "The inspect template ID to be used on the DLP job trigger."
  type        = string
}
