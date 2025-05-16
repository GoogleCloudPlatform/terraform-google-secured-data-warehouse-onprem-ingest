locals {
  postgresql_enabled = var.database_type == "POSTGRES"
}

module "postgresql" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  count = local.postgresql_enabled ? 1 : 0

  name                        = "data-warehouse"
  random_instance_name        = true
  project_id                  = var.data_project_id
  database_version            = var.postgresql.version
  maintenance_version         = var.postgresql.maintenance_version
  deletion_protection         = var.postgresql.deletion_protection_enabled
  deletion_protection_enabled = var.postgresql.deletion_protection_enabled
  database_flags = [
    {
      name  = "cloudsql_iam_authentication"
      value = "on"
    }
  ]

  iam_users = [
    {
      email = var.plaintext_reader_group
      type  = "CLOUD_IAM_GROUP"
    },
    {
      email = var.encrypted_data_reader_group
      type  = "CLOUD_IAM_GROUP"
    }
  ]
}

resource "google_project_iam_member" "sql_groups_instance_users" {
  for_each = toset(
    [
      var.plaintext_reader_group,
      var.encrypted_data_reader_group,
    ]
  )

  role    = "roles/cloudsql.instanceUser"
  project = var.data_project_id
  member  = "group:${each.key}"
}
