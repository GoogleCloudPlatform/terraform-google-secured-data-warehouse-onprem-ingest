/**
 * Copyright 2025 Google LLC
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
  description = "Project ID where the SQL instace will be created."
  type        = string
}

variable "database_version" {
  description = "The database version to use."
  type        = string
}

variable "region" {
  description = "The region where the Cloud SQL instance will be created."
  type        = string
}

variable "edition" {
  description = "The edition of the Cloud SQL instance. Can be \"ENTERPRISE\" or \"ENTERPRISE_PLUS\""
  type        = string
}

variable "tier" {
  description = "The tier for the Cloud SQL instance."
  type        = string
}

variable "maintenance_version" {
  description = "The current software version on the instance. This attribute can not be set during creation. Refer to available_maintenance_versions attribute to see what maintenance_version are available for upgrade. When this attribute gets updated, it will cause an instance restart. Setting a maintenance_version value that is older than the current one on the instance will be ignored."
  type        = string
}

variable "maintenance_window_day" {
  description = "The day of week (1-7) for the Cloud SQL instance maintenance."
  type        = number
}

variable "maintenance_window_hour" {
  description = "The hour of day (0-23) maintenance window for the Cloud SQL instance maintenance."
  type        = number
}

variable "deletion_protection" {
  description = "Enables protection of an Cloud SQL instance from accidental deletion across all surfaces (API, gcloud, Cloud Console and Terraform)."
  type        = bool
}

variable "database_flags" {
  description = "The database flags for the Cloud SQL instance."
  type = list(
    object(
      {
        name  = string
        value = string
      }
    )
  )
}

variable "plaintext_reader_group" {
  description = "Google Cloud IAM group that analyzes plaintext reader."
  type        = string
}

variable "encrypted_data_reader_group" {
  description = "Google Cloud IAM group that analyzes encrypted data."
  type        = string
}
