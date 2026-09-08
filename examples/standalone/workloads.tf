/**
 * Copyright 2023-2025 Google LLC
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
  sensitive_tags = {
    credit_limit = {
      display_name = "CREDIT_LIMIT"
      description  = "Credit allowed to individual."
    }
    card_type_full_name = {
      display_name = "CARD_TYPE_FULL_NAME"
      description  = "Credit card type full name."
    }
    card_type_code = {
      display_name = "CARD_TYPE_CODE"
      description  = "Credit card type code."
    }
  }

  masked_reader_groups = {
    data_analyst     = var.data_analyst_group
    encrypted_data   = var.encrypted_data_reader_group
    plaintext_reader = var.plaintext_reader_group
  }

  dlp_output_dataset       = "dlp_scanner_output"
  table_id                 = "credit_card"
  decrypt_function_id      = "decrypt"
  taxonomy_name            = "secured_taxonomy"
  taxonomy_display_name    = "${local.taxonomy_name}-${random_string.suffix.result}"
  csv_load_job_id          = "job_load_csv_${random_string.suffix.result}"
  bq_schema                = "Card_Type_Code:STRING, Card_Type_Full_Name:STRING, Issuing_Bank:STRING, Card_Number:STRING, Card_Holders_Name:STRING, CVV_CVV2:STRING, Issue_Date:STRING, Expiry_Date:STRING, Billing_Date:STRING, Card_PIN:STRING, Credit_Limit:STRING"
  kek_keyring              = "kek_keyring_${random_string.suffix.result}"
  kek_key_name             = "kek_key_${random_string.suffix.result}"
  kek_users                = "serviceAccount:${var.terraform_service_account},group:${var.plaintext_reader_group}"
  keys                     = [local.kek_key_name]
  encrypters               = [local.kek_users]
  decrypters               = [local.kek_users]
  keyset_file              = "keyset_${random_string.suffix.result}.json"
  encrypted_data_csv_file  = "encrypted_${random_string.suffix.result}.csv"
  encrypted_data_json_file = "encrypted_${random_string.suffix.result}.json"
  tags                     = ["vpc-connector"]

}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

/**
* BigQuery column-level access control.
* See: https://cloud.google.com/bigquery/docs/column-level-security-intro
*
* Creates a BigQuery table with column-level access control managed
* by a Data Catalog Taxonomy
*/
resource "google_data_catalog_taxonomy" "secure_taxonomy" {
  project                = module.harness_projects.data_governance_project_id
  region                 = local.location
  display_name           = local.taxonomy_display_name
  description            = "Taxonomy created for Sample Sensitive Data"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]

  depends_on = [
    module.secured_data_warehouse_onprem_ingest
  ]
}
resource "google_data_catalog_policy_tag" "policy_tag_sensitive" {
  taxonomy     = google_data_catalog_taxonomy.secure_taxonomy.id
  display_name = "1_Sensitive"
  description  = "Data not meant to be public."
}

resource "google_data_catalog_policy_tag" "sensitive_tags" {
  for_each = local.sensitive_tags

  taxonomy          = google_data_catalog_taxonomy.secure_taxonomy.id
  display_name      = each.value["display_name"]
  description       = each.value["description"]
  parent_policy_tag = google_data_catalog_policy_tag.policy_tag_sensitive.id
}

resource "google_bigquery_datapolicy_data_policy" "credit_limit" {
  project          = module.harness_projects.data_governance_project_id
  location         = local.location
  data_policy_id   = "credit_limit"
  policy_tag       = google_data_catalog_policy_tag.sensitive_tags["credit_limit"].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "DEFAULT_MASKING_VALUE"
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "credit_limit" {
  for_each = local.masked_reader_groups

  project        = google_bigquery_datapolicy_data_policy.credit_limit.project
  location       = google_bigquery_datapolicy_data_policy.credit_limit.location
  data_policy_id = google_bigquery_datapolicy_data_policy.credit_limit.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = "group:${each.value}"
}

resource "google_bigquery_datapolicy_data_policy" "card_type_full_name" {
  project          = module.harness_projects.data_governance_project_id
  location         = local.location
  data_policy_id   = "card_type_full_name"
  policy_tag       = google_data_catalog_policy_tag.sensitive_tags["card_type_full_name"].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "DEFAULT_MASKING_VALUE"
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "card_type_full_name" {
  for_each = local.masked_reader_groups

  project        = google_bigquery_datapolicy_data_policy.card_type_full_name.project
  location       = google_bigquery_datapolicy_data_policy.card_type_full_name.location
  data_policy_id = google_bigquery_datapolicy_data_policy.card_type_full_name.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = "group:${each.value}"
}

resource "google_bigquery_datapolicy_data_policy" "card_type_code" {
  project          = module.harness_projects.data_governance_project_id
  location         = local.location
  data_policy_id   = "card_type_code"
  policy_tag       = google_data_catalog_policy_tag.sensitive_tags["card_type_code"].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "DEFAULT_MASKING_VALUE"
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "card_type_code_member" {
  for_each = local.masked_reader_groups

  project        = google_bigquery_datapolicy_data_policy.card_type_code.project
  location       = google_bigquery_datapolicy_data_policy.card_type_code.location
  data_policy_id = google_bigquery_datapolicy_data_policy.card_type_code.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = "group:${each.value}"
}

data "google_bigquery_default_service_account" "bq_sa" {
  project = module.harness_projects.data_project_id
}

resource "google_data_catalog_taxonomy_iam_binding" "data_bq_binding" {
  project  = module.harness_projects.data_governance_project_id
  taxonomy = google_data_catalog_taxonomy.secure_taxonomy.name
  role     = "roles/datacatalog.categoryFineGrainedReader"
  members = [
    "serviceAccount:${data.google_bigquery_default_service_account.bq_sa.email}",
    "group:${var.plaintext_reader_group}"
  ]
}

resource "google_data_catalog_taxonomy_iam_binding" "cloudfunction_sa_viewer" {
  project  = module.harness_projects.data_governance_project_id
  taxonomy = google_data_catalog_taxonomy.secure_taxonomy.name
  role     = "roles/datacatalog.viewer"
  members = [
    "serviceAccount:${module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email}"
  ]
}

resource "google_bigquery_table" "credit_card" {
  dataset_id          = local.dataset_id
  project             = module.harness_projects.data_project_id
  table_id            = local.table_id
  friendly_name       = local.table_id
  deletion_protection = !var.delete_contents_on_destroy

  schema = templatefile("${path.module}/templates/schema.template",
    {
      pt_credit_limit        = google_data_catalog_policy_tag.sensitive_tags["credit_limit"].id
      pt_card_type_full_name = google_data_catalog_policy_tag.sensitive_tags["card_type_full_name"].id
      pt_card_type_code      = google_data_catalog_policy_tag.sensitive_tags["card_type_code"].id
    }
  )

  lifecycle {
    ignore_changes = [
      encryption_configuration # managed by the dataset default_encryption_configuration.
    ]
  }

  depends_on = [
    module.secured_data_warehouse_onprem_ingest
  ]
}

/**
* Upload encrypted files
* See:
* - https://github.com/google/tink/blob/master/docs/TINKEY.md
* - https://github.com/google/tink/blob/master/docs/GOLANG-HOWTO.md
*
* Simulates the creation of data encrypted on prem that will be uploaded
* to the Data project using the infrastructure from the Data Ingestion project.
* The file is encrypted using a key created with Tinkey and helpers
* to encrypt the files.
*
* Note: the Data Encryption Key (DEK) is created here so that the example
* can be deployed with minimal requirements. In a production flow the DEK
* Should be created outside of the Terraform configuration used for the
* creation of the BigQuery Data Warehouse with the appropriated controls
* to preserve it and keep it save.
*/
module "kek_wrapping_key" {
  source  = "terraform-google-modules/kms/google"
  version = "4.1.2"

  project_id           = module.harness_projects.data_governance_project_id
  labels               = { environment = "dev" }
  location             = local.location
  keyring              = local.kek_keyring
  key_rotation_period  = local.key_rotation_period_seconds
  keys                 = local.keys
  key_protection_level = "HSM"
  set_encrypters_for   = local.keys
  set_decrypters_for   = local.keys
  encrypters           = local.encrypters
  decrypters           = local.decrypters
  prevent_destroy      = !var.delete_contents_on_destroy
}

resource "google_kms_crypto_key_iam_member" "plaintext_reader_group_key" {
  crypto_key_id = module.kek_wrapping_key.keys[local.kek_key_name]
  role          = "roles/cloudkms.cryptoKeyDecrypterViaDelegation"
  member        = "group:${var.plaintext_reader_group}"
}

resource "null_resource" "create_wrapped_key" {

  provisioner "local-exec" {
    command = <<EOF
    tinkey create-keyset \
    --key-template AES256_GCM \
    --out-format json --out ${path.module}/${local.keyset_file} \
    --master-key-uri "gcp-kms://${module.kek_wrapping_key.keys[local.kek_key_name]}"
EOF
  }

  depends_on = [
    google_project_iam_binding.remove_owner_role,
    module.kek_wrapping_key
  ]
}

data "external" "dek_wrapped_key" {
  program = [
    "/bin/bash", "${path.module}/helpers/read_key.sh"
  ]

  query = {
    key_file = "${abspath(path.module)}/${local.keyset_file}"
  }

  depends_on = [
    null_resource.create_wrapped_key
  ]
}

resource "null_resource" "encrypt_csv" {

  provisioner "local-exec" {
    command = <<EOF
    cd ${path.module}/helpers/csv-encrypter/ && go run ./csv-encrypter.go \
      --in "${abspath(path.module)}/assets/cc_10000_records.csv" \
      --out "${abspath(path.module)}/${local.encrypted_data_csv_file}" \
      --fields "Card_Number,Card_Holders_Name,CVV_CVV2,Expiry_Date,Card_PIN,Credit_Limit" \
      --keyset ${abspath(path.module)}/${local.keyset_file} \
      --master-key-uri "gcp-kms://${module.kek_wrapping_key.keys[local.kek_key_name]}"
EOF
  }

  depends_on = [
    google_project_iam_binding.remove_owner_role,
    module.kek_wrapping_key,
    null_resource.create_wrapped_key
  ]
}

resource "google_storage_bucket_object" "csv" {
  name   = local.encrypted_data_csv_file
  source = "${abspath(path.module)}/${local.encrypted_data_csv_file}"
  bucket = module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name

  depends_on = [
    null_resource.encrypt_csv
  ]
}

/**
* BigQuery load job
* See: https://cloud.google.com/bigquery/docs/batch-loading-data
*
* Example of loading data using a BigQuery job
*/
resource "google_bigquery_job" "load_job" {
  job_id   = local.csv_load_job_id
  project  = module.harness_projects.data_project_id
  location = local.location

  labels = {
    "type" = "csv_load_data"
  }

  load {
    source_uris = [
      "gs://${module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name}/${google_storage_bucket_object.csv.name}"
    ]

    destination_table {
      project_id = module.harness_projects.data_project_id
      dataset_id = local.dataset_id
      table_id   = google_bigquery_table.credit_card.id
    }

    skip_leading_rows     = 1
    schema_update_options = ["ALLOW_FIELD_RELAXATION", "ALLOW_FIELD_ADDITION"]

    write_disposition = "WRITE_APPEND"
    autodetect        = false
  }

  lifecycle {
    ignore_changes = [
      load[0].destination_encryption_configuration # managed by the dataset default_encryption_configuration.
    ]
  }

  depends_on = [
    null_resource.encrypt_csv,
    google_storage_bucket_object.csv,
    google_bigquery_table.credit_card,
  ]
}

/**
* BigQuery AEAD decrypt view
* See:
* - https://cloud.google.com/bigquery/docs/aead-encryption-concepts
* - https://cloud.google.com/bigquery/docs/reference/standard-sql/aead_encryption_functions
*
* Example of how to decrypt data using BigQuery AEAD functions
*/
data "template_file" "decrypt_function" {
  template = file("${path.module}/templates/decrypt_function.sql")
  vars = {
    kms_resource_name  = "gcp-kms://${module.kek_wrapping_key.keys[local.kek_key_name]}"
    binary_wrapped_key = data.external.dek_wrapped_key.result.encryptedKeyset
  }
}

resource "google_bigquery_routine" "decrypt_function" {
  project         = module.harness_projects.data_project_id
  dataset_id      = local.dataset_id
  routine_id      = local.decrypt_function_id
  routine_type    = "SCALAR_FUNCTION"
  language        = "SQL"
  definition_body = data.template_file.decrypt_function.rendered

  arguments {
    name      = "encodedText"
    data_type = "{\"typeKind\" :  \"STRING\"}"
  }

  return_type = "{\"typeKind\" :  \"STRING\"}"

  depends_on = [
    module.secured_data_warehouse_onprem_ingest
  ]
}

data "template_file" "decrypted_view" {
  template = file("${path.module}/templates/decrypted_view.template")
  vars = {
    decrypt_function = "${local.dataset_id}.${local.decrypt_function_id}"
    full_table_id    = "${module.harness_projects.data_project_id}.${local.dataset_id}.${local.table_id}"
  }
}

resource "google_bigquery_table_iam_member" "encrypted_credit_card_data_viewer" {
  project    = module.harness_projects.data_project_id
  dataset_id = local.dataset_id
  table_id   = google_bigquery_table.credit_card.table_id
  role       = "roles/bigquery.dataViewer"
  member     = "group:${var.encrypted_data_reader_group}"
}

resource "google_bigquery_table_iam_member" "plaintext_credit_card_data_viewer" {
  project    = module.harness_projects.data_project_id
  dataset_id = local.dataset_id
  table_id   = google_bigquery_table.credit_card.table_id
  role       = "roles/bigquery.dataViewer"
  member     = "group:${var.plaintext_reader_group}"
}

resource "google_bigquery_table" "credit_card_decrypted_view" {
  project             = module.harness_projects.data_project_id
  dataset_id          = local.dataset_id
  table_id            = "decrypted_view"
  deletion_protection = false

  view {
    query          = data.template_file.decrypted_view.rendered
    use_legacy_sql = false
  }

  lifecycle {
    ignore_changes = [
      encryption_configuration # managed by the dataset default_encryption_configuration.
    ]
  }

  depends_on = [
    google_bigquery_job.load_job,
    google_bigquery_routine.decrypt_function,
    google_bigquery_table.credit_card
  ]
}

resource "google_bigquery_table_iam_member" "dataViewer" {
  project    = module.harness_projects.data_project_id
  dataset_id = local.dataset_id
  table_id   = google_bigquery_table.credit_card_decrypted_view.table_id
  role       = "roles/bigquery.dataViewer"
  member     = "group:${var.plaintext_reader_group}"
}

/**
* DLP table Scanner
* See: https://cloud.google.com/bigquery/docs/scan-with-dlp
*
* An example of how to configure DLP scanner in a BigQuery table.
* This example uses the default list of info types to do the scanning.
* To choose a specific info type see:
* - https://cloud.google.com/dlp/docs/concepts-infotypes
* - https://cloud.google.com/dlp/docs/infotypes-reference
*/
resource "google_data_loss_prevention_inspect_template" "dlp_inspect_template" {
  parent       = "projects/${module.harness_projects.data_governance_project_id}/locations/${local.location}"
  description  = "Secured DataWarehouse DLP inspect template."
  display_name = "dlp_scanner_inpect_template"
}

module "dlp_scanner" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google//modules/dlp-scanner"
  version = "~> 0.1"

  bq_project_id             = module.harness_projects.data_project_id
  bq_dataset_id             = local.dataset_id
  bq_table_id               = local.table_id
  terraform_service_account = var.terraform_service_account
  dlp_project_id            = module.harness_projects.data_governance_project_id
  dlp_output_dataset        = local.dlp_output_dataset
  dlp_location              = local.location
  dlp_inspect_template_id   = google_data_loss_prevention_inspect_template.dlp_inspect_template.id

  depends_on = [
    module.secured_data_warehouse_onprem_ingest,
    google_data_loss_prevention_inspect_template.dlp_inspect_template
  ]
}

/**
* BigQuery Pub/Sub subscription example
* See: https://cloud.google.com/pubsub/docs/bigquery
*
* An example of how to configure BigQuery Pub/Sub subscription
* to writes Pub/Sub messages to an existing BigQuery table.
*/
module "pubsub_to_bigquery" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 8.0"

  project_id         = module.harness_projects.data_ingestion_project_id
  topic              = "pubsub_to_bigquery_topic"
  topic_kms_key_name = module.secured_data_warehouse_onprem_ingest.cmek_data_ingestion_crypto_key
  create_topic       = true

  schema = {
    name       = "pubsub_to_bigquery_schema"
    type       = "AVRO"
    encoding   = "JSON"
    definition = file("${path.module}/templates/avro.schema.template")
  }

  bigquery_subscriptions = [
    {
      name             = "pubsub_to_bigquery_subscription"
      table            = "${module.harness_projects.data_project_id}:${module.secured_data_warehouse_onprem_ingest.dataset_id}.${google_bigquery_table.credit_card.table_id}"
      use_topic_schema = true
    }
  ]

  depends_on = [
    module.secured_data_warehouse_onprem_ingest,
    module.harness_projects
  ]
}

resource "null_resource" "encrypt_json" {

  provisioner "local-exec" {
    command = <<EOF
    cd ${path.module}/helpers/json-encrypter/ && go run ./json-encrypter.go \
      --in "${abspath(path.module)}/assets/cc_100_records.json" \
      --out "${abspath(path.module)}/${local.encrypted_data_json_file}" \
      --fields "Card_Number,Card_Holders_Name,CVV_CVV2,Expiry_Date,Card_PIN,Credit_Limit" \
      --keyset ${abspath(path.module)}/${local.keyset_file} \
      --master-key-uri "gcp-kms://${module.kek_wrapping_key.keys[local.kek_key_name]}"
    EOF
  }

  depends_on = [
    google_project_iam_binding.remove_owner_role,
    module.kek_wrapping_key,
    null_resource.create_wrapped_key
  ]
}

resource "null_resource" "enqueue_messages_to_bigquery_subscription" {

  provisioner "local-exec" {
    command = <<EOF
    pubsub_topic_id="${module.pubsub_to_bigquery.id}"
    input_data="${abspath(path.module)}/${local.encrypted_data_json_file}"

    while read line; do
    if [ ! -z "$line" -a "$line" != " " ]; then
        gcloud pubsub topics publish $pubsub_topic_id --message "$line"
    fi
    done < $input_data
    EOF
  }

  depends_on = [
    module.secured_data_warehouse_onprem_ingest,
    module.pubsub_to_bigquery,
    null_resource.encrypt_json
  ]
}


/**
* Cloud Function infrastructure
*
* Required infrastructure to deploy a cloud function in the perimeter
*/
resource "google_project_service_identity" "vpcaccess_identity_sa" {
  provider = google-beta

  project = module.harness_projects.data_ingestion_project_id
  service = "vpcaccess.googleapis.com"
}

resource "google_project_service_identity" "run_identity_sa" {
  provider = google-beta

  project = module.harness_projects.data_ingestion_project_id
  service = "run.googleapis.com"
}

resource "google_project_iam_member" "gca_sa_vpcaccess" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${google_project_service_identity.vpcaccess_identity_sa.email}"
}

resource "google_project_iam_member" "cloud_services" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${module.harness_projects.data_ingestion_project_number}@cloudservices.gserviceaccount.com"
}

resource "google_project_iam_member" "run_identity_services" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/vpcaccess.user"
  member  = "serviceAccount:${google_project_service_identity.run_identity_sa.email}"
}

module "serverless_connector" {
  source  = "terraform-google-modules/network/google//modules/vpc-serverless-connector-beta"
  version = "~> 10.0.0"

  project_id = module.harness_projects.data_ingestion_project_id
  vpc_connectors = [{
    name            = "con-cf-data-ingestion"
    region          = local.location
    host_project_id = module.harness_projects.data_ingestion_project_id
    machine_type    = "e2-micro"
    min_instances   = 2
    max_instances   = 7
    subnet_name     = module.harness_projects.data_ingestion_subnet_name
    }
  ]
  depends_on = [
    google_project_iam_member.gca_sa_vpcaccess,
    google_project_iam_member.cloud_services,
    google_project_iam_member.run_identity_services,
    module.harness_projects.data_ingestion_subnets_self_link
  ]
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "10.0.0"

  project_id   = module.harness_projects.data_ingestion_project_id
  network_name = module.harness_projects.data_ingestion_network_name

  rules = [{
    name                    = "serverless-to-vpc-connector"
    description             = null
    priority                = null
    direction               = "INGRESS"
    ranges                  = ["107.178.230.64/26", "35.199.224.0/19"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = local.tags
    target_service_accounts = null
    allow = [{
      protocol = "icmp"
      ports    = []
      },
      {
        protocol = "tcp"
        ports    = ["667"]
      },
      {
        protocol = "udp"
        ports    = ["665", "666"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    },
    {
      name                    = "vpc-connector-to-serverless"
      description             = null
      priority                = null
      direction               = "EGRESS"
      ranges                  = ["107.178.230.64/26", "35.199.224.0/19"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = local.tags
      target_service_accounts = null
      allow = [{
        protocol = "icmp"
        ports    = []
        },
        {
          protocol = "tcp"
          ports    = ["667"]
        },
        {
          protocol = "udp"
          ports    = ["665", "666"]
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "vpc-connector-to-lb"
      description             = null
      priority                = null
      direction               = "EGRESS"
      ranges                  = []
      source_tags             = null
      source_service_accounts = null
      target_tags             = local.tags
      target_service_accounts = null
      allow = [{
        protocol = "tcp"
        ports    = ["80"]
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "vpc-connector-health-checks"
      description             = null
      priority                = null
      direction               = "INGRESS"
      ranges                  = ["130.211.0.0/22", "35.191.0.0/16", "108.170.220.0/23"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = local.tags
      target_service_accounts = null
      allow = [{
        protocol = "tcp"
        ports    = ["667"]
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "vpc-connector-requests"
      description             = null
      priority                = null
      direction               = "INGRESS"
      ranges                  = []
      source_tags             = local.tags
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [{
        protocol = "icmp"
        ports    = []
        },
        {
          protocol = "tcp"
          ports    = []
        },
        {
          protocol = "udp"
          ports    = []
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}

resource "google_artifact_registry_repository" "cloudfunction_repo" {
  location      = local.location
  project       = module.harness_projects.data_ingestion_project_id
  repository_id = "rep-cloud-function"
  description   = "This repo stores the image of the cloud function"
  format        = "DOCKER"
  kms_key_name  = module.secured_data_warehouse_onprem_ingest.cmek_data_ingestion_crypto_key
}

/**
* File upload Cloud Function Deploy
*
* An example of a Cloud Function to create BigQuery load jobs
* when a file is uploaded to a Google Cloud Storage bucket.
*/
resource "google_eventarc_google_channel_config" "primary" {
  location        = local.location
  name            = "projects/${module.harness_projects.data_ingestion_project_id}/locations/${local.location}/googleChannelConfig"
  project         = module.harness_projects.data_ingestion_project_id
  crypto_key_name = module.secured_data_warehouse_onprem_ingest.cmek_data_ingestion_crypto_key
}


data "google_storage_project_service_account" "gcs_account" {
  project = module.harness_projects.data_ingestion_project_id
}

# To use GCS CloudEvent triggers, the GCS service account requires the Pub/Sub Publisher(roles/pubsub.publisher) IAM role in the specified project.
# (See https://cloud.google.com/eventarc/docs/run/quickstart-storage#before-you-begin)
resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
  depends_on = [
    module.harness_projects
  ]
}

resource "google_project_service_identity" "eventarc_identity_sa" {
  provider = google-beta

  project = module.harness_projects.data_ingestion_project_id
  service = "eventarc.googleapis.com"
  depends_on = [
    module.harness_projects
  ]
}

# Permissions on the service account used by the function and Eventarc trigger
resource "google_project_iam_member" "invoking" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email}"
}

# Permissions on the cloud function service account to Edit data in BQ
resource "google_project_iam_member" "bq_data_editor" {
  project = module.harness_projects.data_project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email}"
}

# Permissions on the cloud function service account to run BQ Jobs
resource "google_project_iam_member" "bq_job_user" {
  project = module.harness_projects.data_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email}"
}

# Forces Service Agent role due to propagation issue.
resource "google_project_iam_member" "eventarc_serviceAgent" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/eventarc.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.eventarc_identity_sa.email}"
  depends_on = [
    module.harness_projects
  ]
}

resource "google_project_iam_member" "artifactregistry_reader" {
  project = module.harness_projects.data_ingestion_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.terraform_service_account}"
  depends_on = [
    module.harness_projects
  ]
}

# Add function source code to a zip file
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/cloudfunction-${random_string.suffix.result}.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = module.secured_data_warehouse_onprem_ingest.data_ingestion_cloudfunction_bucket_name

  depends_on = [
    data.archive_file.source
  ]
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.eventarc_serviceAgent,
    google_project_iam_member.artifactregistry_reader,
    google_storage_bucket_object.zip,
    google_eventarc_google_channel_config.primary,
    google_bigquery_job.load_job
  ]
}

resource "google_cloudfunctions2_function" "function" {
  depends_on = [
    time_sleep.wait_iam_propagation
  ]

  name        = "cf-load-csv"
  project     = module.harness_projects.data_ingestion_project_id
  location    = local.location
  description = "Cloud Function created to read CSV files from data ingestion bucket and write in the Bigquery table."

  build_config {
    runtime     = "python310"
    entry_point = "csv_loader" # Set the entry point in the code
    environment_variables = {
      BUCKET : module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name
    }
    docker_repository = google_artifact_registry_repository.cloudfunction_repo.id
    source {
      storage_source {
        bucket = module.secured_data_warehouse_onprem_ingest.data_ingestion_cloudfunction_bucket_name
        object = google_storage_bucket_object.zip.name
      }
    }
    service_account = "projects/${module.harness_projects.data_ingestion_project_id}/serviceAccounts/${module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email}"
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      BUCKET : module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name
      DATASET_PROJECT_ID : module.harness_projects.data_project_id
      DATASET : module.secured_data_warehouse_onprem_ingest.dataset_id
      TABLE : google_bigquery_table.credit_card.table_id
      VERSION : "v1.0"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email
    vpc_connector                  = tolist(module.serverless_connector.connector_ids)[0]
    vpc_connector_egress_settings  = "ALL_TRAFFIC"
  }

  event_trigger {                          # bucket which will trigger the CF when new data is uploaded
    trigger_region        = local.location # The trigger must be in the same location as the bucket
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = module.secured_data_warehouse_onprem_ingest.cloudfunction_controller_service_account_email
    event_filters {
      attribute = "bucket"
      value     = module.secured_data_warehouse_onprem_ingest.data_ingestion_bucket_name
    }
  }
}

/**
* Dataflow flex job deploy
* See: https://cloud.google.com/dataflow/docs/guides/templates/using-flex-templates
*
* An example of a Dataflow job that ingest data from Pub/Sub in to BigQuery
* and can do a transformation in the data being ingested.
*/
# Permission to let datafow service account to access the templates
resource "google_artifact_registry_repository_iam_member" "docker_reader" {
  project    = module.harness_artifact_registry_project.project_id
  location   = local.location
  repository = "flex-templates"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.secured_data_warehouse_onprem_ingest.dataflow_controller_service_account_email}"

  depends_on = [
    module.secured_data_warehouse_onprem_ingest
  ]
}

# Permission to let dataflow service account to access the templates
resource "google_artifact_registry_repository_iam_member" "python_reader" {
  project    = module.harness_artifact_registry_project.project_id
  location   = local.location
  repository = "python-modules"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.secured_data_warehouse_onprem_ingest.dataflow_controller_service_account_email}"

  depends_on = [
    module.secured_data_warehouse_onprem_ingest
  ]
}

resource "google_dataflow_flex_template_job" "dataflow_flex_template_job" {
  provider = google-beta

  project                 = module.harness_projects.data_ingestion_project_id
  name                    = "pubsub-dataflow-to-bigqquery"
  container_spec_gcs_path = module.build_flex_template.template_gs_path
  region                  = local.location
  on_delete               = "cancel"
  service_account_email   = module.secured_data_warehouse_onprem_ingest.dataflow_controller_service_account_email

  max_workers             = 1
  enable_streaming_engine = true
  staging_location        = "gs://${module.secured_data_warehouse_onprem_ingest.data_ingestion_dataflow_bucket_name}/staging/"
  temp_location           = "gs://${module.secured_data_warehouse_onprem_ingest.data_ingestion_dataflow_bucket_name}/tmp/"
  kms_key_name            = module.secured_data_warehouse_onprem_ingest.cmek_data_ingestion_crypto_key
  subnetwork              = module.harness_projects.data_ingestion_subnets_self_link
  ip_configuration        = "WORKER_IP_PRIVATE"
  machine_type            = "n2d-standard-2" # For confidential computing supported machines list access: <https://cloud.google.com/confidential-computing/confidential-vm/docs/supported-configurations>
  additional_experiments = [
    "enable_kms_on_streaming_engine",
    "enable_confidential_compute",
  ]

  parameters = {
    input_topic  = "projects/${module.harness_projects.data_ingestion_project_id}/topics/${module.secured_data_warehouse_onprem_ingest.data_ingestion_topic_name}"
    bq_schema    = local.bq_schema
    output_table = "${module.harness_projects.data_project_id}:${local.dataset_id}.${local.table_id}"
  }

  depends_on = [
    google_artifact_registry_repository_iam_member.docker_reader,
    google_artifact_registry_repository_iam_member.python_reader,
  ]
}
