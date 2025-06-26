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
  perimeter_members_data_ingestion = distinct(concat([
    "serviceAccount:${module.data_ingestion_sa.dataflow_controller_service_account_email}",
    "serviceAccount:${module.data_ingestion_sa.storage_writer_service_account_email}",
    "serviceAccount:${module.data_ingestion_sa.pubsub_writer_service_account_email}",
    "serviceAccount:${module.data_ingestion_sa.cloudfunction_controller_service_account_email}",
    "serviceAccount:${google_project_service_identity.eventarc_identity_sa.email}",
    "serviceAccount:${google_project_service_identity.cloudbuild_identity_sa.email}",
    "serviceAccount:${google_project_service_identity.dlp_identity_sa.email}",
    "serviceAccount:${var.terraform_service_account}"
  ], var.perimeter_additional_members))

  perimeter_members_governance = distinct(concat([
    "serviceAccount:${var.terraform_service_account}"
  ], var.perimeter_additional_members))

  perimeter_members_data = distinct(concat([
    "serviceAccount:${var.terraform_service_account}"
  ], var.perimeter_additional_members))

  supported_restricted_service = [
    "accessapproval.googleapis.com",
    "adsdatahub.googleapis.com",
    "aiplatform.googleapis.com",
    "alloydb.googleapis.com",
    "alpha-documentai.googleapis.com",
    "analyticshub.googleapis.com",
    "apigee.googleapis.com",
    "apigeeconnect.googleapis.com",
    "artifactregistry.googleapis.com",
    "assuredworkloads.googleapis.com",
    "automl.googleapis.com",
    "baremetalsolution.googleapis.com",
    "batch.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "bigquerymigration.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "bigtable.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloud.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddebugger.googleapis.com",
    "clouddeploy.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudprofiler.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudsearch.googleapis.com",
    "cloudtrace.googleapis.com",
    "composer.googleapis.com",
    "compute.googleapis.com",
    "connectgateway.googleapis.com",
    "contactcenterinsights.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerfilesystem.googleapis.com",
    "containerregistry.googleapis.com",
    "containerthreatdetection.googleapis.com",
    "datacatalog.googleapis.com",
    "dataflow.googleapis.com",
    "datafusion.googleapis.com",
    "datamigration.googleapis.com",
    "dataplex.googleapis.com",
    "dataproc.googleapis.com",
    "datastream.googleapis.com",
    "dialogflow.googleapis.com",
    "dlp.googleapis.com",
    "dns.googleapis.com",
    "documentai.googleapis.com",
    "domains.googleapis.com",
    "eventarc.googleapis.com",
    "file.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebaserules.googleapis.com",
    "firestore.googleapis.com",
    "gameservices.googleapis.com",
    "gkebackup.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "healthcare.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iaptunnel.googleapis.com",
    "ids.googleapis.com",
    "integrations.googleapis.com",
    "kmsinventory.googleapis.com",
    "krmapihosting.googleapis.com",
    "language.googleapis.com",
    "lifesciences.googleapis.com",
    "logging.googleapis.com",
    "managedidentities.googleapis.com",
    "memcache.googleapis.com",
    "meshca.googleapis.com",
    "meshconfig.googleapis.com",
    "metastore.googleapis.com",
    "ml.googleapis.com",
    "monitoring.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networkmanagement.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
    "notebooks.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "osconfig.googleapis.com",
    "oslogin.googleapis.com",
    "privateca.googleapis.com",
    "pubsub.googleapis.com",
    "pubsublite.googleapis.com",
    "recaptchaenterprise.googleapis.com",
    "recommender.googleapis.com",
    "redis.googleapis.com",
    "retail.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicedirectory.googleapis.com",
    "spanner.googleapis.com",
    "speakerid.googleapis.com",
    "speech.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "storagetransfer.googleapis.com",
    "sts.googleapis.com",
    "texttospeech.googleapis.com",
    "timeseriesinsights.googleapis.com",
    "tpu.googleapis.com",
    "trafficdirector.googleapis.com",
    "transcoder.googleapis.com",
    "translate.googleapis.com",
    "videointelligence.googleapis.com",
    "vision.googleapis.com",
    "visionai.googleapis.com",
    "vmmigration.googleapis.com",
    "vpcaccess.googleapis.com",
    "webrisk.googleapis.com",
    "workflows.googleapis.com",
    "workstations.googleapis.com",
  ]

  restricted_services = length(var.custom_restricted_services) != 0 ? var.custom_restricted_services : local.supported_restricted_service

  actual_policy = var.access_context_manager_policy_id != "" ? var.access_context_manager_policy_id : google_access_context_manager_access_policy.access_policy[0].name

  data_ingestion_default_ingress_rule = var.sdx_project_number == "" ? [] : [
    # You can add here default ingress policies if necessary
  ]

  data_ingestion_default_egress_rule = var.sdx_project_number == "" ? [] : [
    {
      "from" = {
        "identities" = distinct(concat(
          var.data_ingestion_dataflow_deployer_identities,
          ["serviceAccount:${var.terraform_service_account}"],
          ["serviceAccount:${module.data_ingestion_sa.dataflow_controller_service_account_email}"]
        ))
      },
      "to" = {
        "resources" = ["projects/${var.sdx_project_number}"]
        "operations" = {
          "storage.googleapis.com" = {
            "methods" = [
              "google.storage.objects.get"
            ]
          }
          "artifactregistry.googleapis.com" = {
            "methods" = [
              "*"
            ]
          }
        }
      }
    },
  ]

  data_governance_default_ingress_rule = var.sdx_project_number == "" ? [] : [
    # You can add here default ingress policies if necessary
  ]

  data_governance_default_egress_rule = var.sdx_project_number == "" ? [] : [
    # You can add here default egress policies if necessary
  ]

  data_default_ingress_rule = var.sdx_project_number == "" ? [] : [
    {
      "from" = {
        "identities" = distinct(concat(
          ["serviceAccount:service-${var.data_ingestion_project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"]
        )),
        "sources" = {
          "resources" = ["projects/${var.data_ingestion_project_number}"]
        }
      },
      "to" = {
        "resources" = ["*"],
        "operations" = {
          "bigquery.googleapis.com" = {
            "methods" = [
              "*"
            ]
          },
        }
      }
    }
  ]

  data_default_egress_rule = var.sdx_project_number == "" ? [] : [
    # You can add here default egress policies if necessary
  ]
}

resource "google_project_iam_member" "bigquery_metadata_viewer_binding" {
  project = var.data_project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:service-${var.data_ingestion_project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "bigquery_data_editor_binding" {
  project = var.data_project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${var.data_ingestion_project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_service_identity" "eventarc_identity_sa" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "eventarc.googleapis.com"
}

resource "google_project_service_identity" "cloudbuild_identity_sa" {
  provider = google-beta

  project = var.data_ingestion_project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service_identity" "dlp_identity_sa" {
  provider = google-beta

  project = var.data_project_id
  service = "dlp.googleapis.com"
}

resource "google_access_context_manager_access_policy" "access_policy" {
  count  = var.access_context_manager_policy_id != "" ? 0 : 1
  parent = "organizations/${var.org_id}"
  title  = "default policy"
}

resource "random_id" "suffix" {
  byte_length = 4
}

// It's necessary to use the forces_wait_propagation to guarantee the resources that use this VPC do not have issues related to the propagation.
// See: https://cloud.google.com/vpc-service-controls/docs/manage-service-perimeters#update.
resource "time_sleep" "forces_wait_propagation" {
  destroy_duration = "330s"

  depends_on = [
    module.data_ingestion_sa,
    module.data_governance_sa,
    google_project_iam_member.data-engineer-group-ingestion,
    google_project_iam_member.data-engineer-group,
    google_project_iam_member.data-analyst-group-ingestion,
    google_project_iam_member.data-analyst-group,
    google_organization_iam_member.security-analyst-group,
    google_organization_iam_member.network-administrator-group,
    google_organization_iam_member.security-administrator-group,
    google_project_iam_member.plaintext_reader_group,
    google_project_iam_member.encrypted_data_reader_group,
  ]
}

module "data_ingestion_vpc_sc" {
  source = ".//modules/vpc-sc-config"

  count = var.data_ingestion_perimeter == "" ? 1 : 0

  access_context_manager_policy_id = local.actual_policy
  common_name                      = "data_ingestion"
  common_suffix                    = random_id.suffix.hex
  perimeter_members                = local.perimeter_members_data_ingestion
  restricted_services              = local.restricted_services
  access_level_ip_subnetworks      = var.access_level_ip_subnetworks

  resources = {
    data_ingestion = var.data_ingestion_project_number
  }

  ingress_policies = distinct(concat(
    local.data_ingestion_default_ingress_rule,
    var.data_ingestion_ingress_policies
  ))

  egress_policies = distinct(concat(
    local.data_ingestion_default_egress_rule,
    var.data_ingestion_egress_policies
  ))

  # depends_on block is needed to prevent possible propagation errors
  # e.g. VPC-SC perimeter is created but its members not yet propagated.
  depends_on = [
    time_sleep.forces_wait_propagation
  ]
}

# Adding project to an existing VPC Service Controls Perimeter
# instead of the default VPC Service Controls perimeter.
# The default VPC Service Controls perimeter and access list will not be created.
resource "google_access_context_manager_service_perimeter_resource" "ingestion-perimeter-resource" {
  count = var.data_ingestion_perimeter != "" && var.add_project_to_data_ingestion_perimeter ? 1 : 0

  perimeter_name = "accessPolicies/${local.actual_policy}/servicePerimeters/${var.data_ingestion_perimeter}"
  resource       = "projects/${var.data_ingestion_project_number}"

  depends_on = [
    time_sleep.forces_wait_propagation
  ]
}

module "data_governance_vpc_sc" {
  source = ".//modules/vpc-sc-config"

  count = var.data_governance_perimeter == "" ? 1 : 0

  access_context_manager_policy_id = local.actual_policy
  common_name                      = "data_governance"
  common_suffix                    = random_id.suffix.hex
  perimeter_members                = local.perimeter_members_governance
  restricted_services              = local.restricted_services
  access_level_ip_subnetworks      = var.access_level_ip_subnetworks

  resources = {
    data_governance = var.data_governance_project_number
  }

  ingress_policies = distinct(concat(
    local.data_governance_default_ingress_rule,
    var.data_governance_ingress_policies
  ))

  egress_policies = distinct(concat(
    local.data_governance_default_egress_rule,
    var.data_governance_egress_policies
  ))

  # depends_on block is needed to prevent possible propagation errors
  # e.g. VPC-SC perimeter is created but its members not yet propagated.
  depends_on = [
    module.data_governance_sa,
    time_sleep.forces_wait_propagation
  ]
}

# Adding project to an existing VPC Service Controls Perimeter
# instead of the default VPC Service Controls perimeter.
# The default VPC Service Controls perimeter and access list will not be created.
resource "google_access_context_manager_service_perimeter_resource" "governance-perimeter-resource" {
  count = var.data_governance_perimeter != "" && var.add_project_to_data_governance_perimeter ? 1 : 0

  perimeter_name = "accessPolicies/${local.actual_policy}/servicePerimeters/${var.data_governance_perimeter}"
  resource       = "projects/${var.data_governance_project_number}"

  depends_on = [
    time_sleep.forces_wait_propagation
  ]
}

module "data_vpc_sc" {
  source = ".//modules/vpc-sc-config"

  count = var.data_perimeter == "" ? 1 : 0

  access_context_manager_policy_id = local.actual_policy
  common_name                      = "data"
  common_suffix                    = random_id.suffix.hex
  perimeter_members                = local.perimeter_members_data
  restricted_services              = local.restricted_services
  access_level_ip_subnetworks      = var.access_level_ip_subnetworks

  resources = {
    data = var.data_project_number
  }

  ingress_policies = distinct(concat(
    local.data_default_ingress_rule,
    var.data_ingress_policies
  ))

  egress_policies = distinct(concat(
    local.data_default_egress_rule,
    var.data_egress_policies
  ))

  # depends_on block is needed to prevent possible propagation errors
  # e.g. VPC-SC perimeter is created but its members not yet propagated.
  depends_on = [
    time_sleep.forces_wait_propagation
  ]
}

# Adding project to an existing VPC Service Controls Perimeter
# instead of the default VPC Service Controls perimeter.
# The default VPC Service Controls perimeter and access list will not be created.
resource "google_access_context_manager_service_perimeter_resource" "perimeter-resource" {
  count = var.data_perimeter != "" && var.add_project_to_data_perimeter ? 1 : 0

  perimeter_name = "accessPolicies/${local.actual_policy}/servicePerimeters/${var.data_perimeter}"
  resource       = "projects/${var.data_project_number}"

  depends_on = [
    time_sleep.forces_wait_propagation
  ]
}

module "vpc_sc_bridge_data_ingestion_governance" {
  source  = "terraform-google-modules/vpc-service-controls/google//modules/bridge_service_perimeter"
  version = "6.2.1"

  policy         = local.actual_policy
  perimeter_name = "vpc_sc_bridge_ingestion_to_governance_${random_id.suffix.hex}"
  description    = "VPC-SC bridge between ingestion and governance perimeters"

  resources = [
    var.data_ingestion_project_number,
    var.data_governance_project_number,
  ]

  resource_keys = [
    0, 1
  ]

  depends_on = [
    time_sleep.forces_wait_propagation,
    module.data_governance_vpc_sc,
    module.data_ingestion_vpc_sc,
    google_access_context_manager_service_perimeter_resource.ingestion-perimeter-resource,
    google_access_context_manager_service_perimeter_resource.governance-perimeter-resource,
  ]
}

module "vpc_sc_bridge_data_governance" {
  source  = "terraform-google-modules/vpc-service-controls/google//modules/bridge_service_perimeter"
  version = "6.2.1"

  policy         = local.actual_policy
  perimeter_name = "vpc_sc_bridge_data_to_governance_${random_id.suffix.hex}"
  description    = "VPC-SC bridge between data and governance perimeters"

  resources = [
    var.data_project_number,
    var.data_governance_project_number
  ]

  resource_keys = [
    0, 1
  ]

  depends_on = [
    time_sleep.forces_wait_propagation,
    module.data_vpc_sc,
    module.data_governance_vpc_sc,
    google_access_context_manager_service_perimeter_resource.perimeter-resource,
    google_access_context_manager_service_perimeter_resource.governance-perimeter-resource,
  ]
}

module "vpc_sc_bridge_data_ingestion" {
  source  = "terraform-google-modules/vpc-service-controls/google//modules/bridge_service_perimeter"
  version = "6.2.1"

  policy         = local.actual_policy
  perimeter_name = "vpc_sc_bridge_data_to_ingestion_${random_id.suffix.hex}"
  description    = "VPC-SC bridge between data and ingestion perimeters"

  resources = [
    var.data_project_number,
    var.data_ingestion_project_number
  ]

  resource_keys = [
    0, 1
  ]

  depends_on = [
    time_sleep.forces_wait_propagation,
    module.data_vpc_sc,
    module.data_ingestion_vpc_sc,
    google_access_context_manager_service_perimeter_resource.perimeter-resource,
    google_access_context_manager_service_perimeter_resource.ingestion-perimeter-resource,
  ]
}

resource "time_sleep" "wait_for_bridge_propagation" {
  create_duration = "240s"

  depends_on = [
    module.vpc_sc_bridge_data_ingestion,
    module.vpc_sc_bridge_data_governance,
    module.vpc_sc_bridge_data_ingestion_governance
  ]
}
