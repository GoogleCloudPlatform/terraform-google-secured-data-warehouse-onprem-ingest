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
locals {
  user_name = "default"
}

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  name                 = "data-warehouse"
  random_instance_name = true
  project_id           = var.project_id
  database_version     = var.database_version
  region               = var.region

  tier = var.tier

  maintenance_version     = var.maintenance_version
  maintenance_window_day  = var.maintenance_window_day
  maintenance_window_hour = var.maintenance_window_hour

  deletion_protection         = var.deletion_protection
  deletion_protection_enabled = var.deletion_protection

  database_flags = concat(
    [
      {
        name  = "cloudsql_iam_authentication"
        value = "on"
      }
    ],
    var.database_flags,
  )
  user_name = local.user_name
  iam_users = [
    {
      id    = "PLAINTEXT_READER_GROUP"
      email = var.plaintext_reader_group
      type  = "CLOUD_IAM_GROUP"
    },
    {
      id    = "ENCRYPTED_DATA_READER_GROUP"
      email = var.encrypted_data_reader_group
      type  = "CLOUD_IAM_GROUP"
    }
  ]
}

resource "google_project_iam_member" "instance_users" {
  for_each = toset(
    [
      var.plaintext_reader_group,
      var.encrypted_data_reader_group,
    ]
  )

  role    = "roles/cloudsql.instanceUser"
  project = var.project_id
  member  = "group:${each.key}"
}
