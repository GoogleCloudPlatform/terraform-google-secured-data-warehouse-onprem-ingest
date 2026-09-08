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
  terraform_service_account = data.terraform_remote_state.shared_env.outputs.terraform_service_accounts["bu1-sdw-app"]
  plaintext_reader_group    = data.terraform_remote_state.projects_env.outputs.plaintext_reader_group

  data_governance_project_id = data.terraform_remote_state.projects_env.outputs.data_governance_project_id
  location                   = data.terraform_remote_state.projects_env.outputs.default_region

  kek_keyring                 = "kek_keyring_${random_string.suffix.result}"
  kek_key_name                = "kek_key_${random_string.suffix.result}"
  key_rotation_period_seconds = "2592000s" #30 days
  kek_users                   = "serviceAccount:${local.terraform_service_account},group:${local.plaintext_reader_group}"
  keys                        = [local.kek_key_name]
  encrypters                  = [local.kek_users]
  decrypters                  = [local.kek_users]

}

data "terraform_remote_state" "projects_env" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/projects/business_unit_1/production"
  }
}

data "terraform_remote_state" "shared_env" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/projects/business_unit_1/shared"
  }
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

// encrypted table example
module "kek_wrapping_key" {
  source  = "terraform-google-modules/kms/google"
  version = "4.1.2"

  project_id           = local.data_governance_project_id
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
  prevent_destroy      = false
}

resource "google_kms_crypto_key_iam_member" "plaintext_reader_group_key" {

  crypto_key_id = module.kek_wrapping_key.keys[local.kek_key_name]
  role          = "roles/cloudkms.cryptoKeyDecrypterViaDelegation"
  member        = "group:${local.plaintext_reader_group}"
}
