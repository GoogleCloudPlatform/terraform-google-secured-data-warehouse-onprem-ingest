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
  postgresql_enabled = var.database_type == "POSTGRES"
}

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  count = local.postgresql_enabled ? 1 : 0

  name                 = "data-warehouse"
  random_instance_name = true
  project_id           = var.data_project_id
  database_version     = var.postgresql.version
  region               = var.location

  tier                            = var.postgresql.tier
  availability_type               = var.postgresql.availability_type
  maintenance_version             = var.postgresql.maintenance_version
  maintenance_window_day          = var.postgresql.maintenance_window_day
  maintenance_window_hour         = var.postgresql.maintenance_window_hour
  maintenance_window_update_track = var.postgresql.maintenance_window_update_track

  deletion_protection         = var.postgresql.deletion_protection_enabled
  deletion_protection_enabled = var.postgresql.deletion_protection_enabled

  database_flags = concat(
    [
      {
        name  = "cloudsql_iam_authentication"
        value = "on"
      }
    ],
    var.postgresql.database_flags,
  )
  ip_configuration = {
    ssl_mode     = "ENCRYPTED_ONLY"
    ipv4_enabled = true
  }

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

resource "google_project_iam_member" "sql_groups_instance_users" {
  for_each = toset(
    local.postgresql_enabled ?
    [
      var.plaintext_reader_group,
      var.encrypted_data_reader_group,
    ]
    :
    []
  )

  role    = "roles/cloudsql.instanceUser"
  project = var.data_project_id
  member  = "group:${each.key}"
}
