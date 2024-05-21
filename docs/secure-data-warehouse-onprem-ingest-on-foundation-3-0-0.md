# How to customize Foundation v3.0.0 for Secured Data Warehouse Onprem Ingest Blueprint deployment

These instructions explain how to deploy the [Secured Data Warehouse Onprem Ingest Blueprint](https://github.com/GoogleCloudPlatform/terraform-google-secured-data-warehouse-onprem-ingest) on top of the [Terraform Example Foundation](https://cloud.google.com/architecture/security-foundations/using-example-terraform) version [v3.0.0](https://github.com/terraform-google-modules/terraform-example-foundation/tree/v3.0.0).

## Overview

The deploy of the Blueprint will use the `production` environment of the business unit 1
of an existing Terraform Example Foundation and will deploy/create:

- The infrastructure required by the Blueprint (*harness*),
- The Blueprint itself,
- An example of the usage of the [Tink](https://github.com/google/tink) library to encrypt data,
- A BigQuery load job to upload the encrypted data to BigQuery,
- Usage of BigQuery [AEAD](https://cloud.google.com/bigquery/docs/reference/standard-sql/aead_encryption_functions) functions to decrypt the data.

The following infrastructure will be created or reused:

- The restricted VPC Service Controls (VPC-SC) perimeter and the shared VPC created in step `3-networks` will be used.
- Four new project will be created in step `4-projects`:
  - The Data Ingestion project that will be added to the existing restricted perimeter and shared VPC.
  - The Data Governance project that will be added to a new VPC-SC perimeter.
  - The Data  project that will be added to another new VPC-SC perimeter.
  - An additional project, outside of any perimeter to host Dataflow template images.
- The Blueprint infrastructure.
- A Cloud Key Management Service (KMS) encryption key for [Envelope encryption](https://cloud.google.com/kms/docs/envelope-encryption).
- A BigQuery table to host encrypted data.
- A BigQuery function tha uses AEAD to decrypt the encrypted data.
- A BigQuery view to show the decrypted data.

For additional examples of workload dependent controls that can be deployed using the blueprint, see the `workloads.tf` file [Standalone Example](../../examples/standalone).

## Requirements

### Code

- [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation/tree/v2.3.1) version 3.0.0 deployed until at least step `4-projects`.
- You must have role **Service Account User** (`roles/iam.serviceAccountUser`) on the [Terraform Service Accounts](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/docs/GLOSSARY.md#terraform-service-account) created in the foundation [Seed Project](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/docs/GLOSSARY.md#seed-project).
  The Terraform Service Accounts have the permissions to deploy each step of the foundation. Service Accounts:
  - `sa-terraform-bootstrap@<SEED_PROJECT_ID>.iam.gserviceaccount.com`.
  - `sa-terraform-env@<SEED_PROJECT_ID>.iam.gserviceaccount.com`
  - `sa-terraform-net@<SEED_PROJECT_ID>.iam.gserviceaccount.com`
  - `sa-terraform-proj@<SEED_PROJECT_ID>.iam.gserviceaccount.com`

### Software

Install the following dependencies:

- [Google Cloud SDK](https://cloud.google.com/sdk/install) version 400.0.0 or later.
- [Terraform](https://www.terraform.io/downloads.html) version 1.3.1 or later.
- [jq](https://stedolan.github.io/jq/) version 1.6 or later.
- [tinkey](https://github.com/google/tink/blob/master/docs/TINKEY.md) version 1.7.0 or later.

### Cloud SDK configurations

These instructions use `tinkey` to generate the wrapped_key that will be used to encrypt data.
The `tinkey` tool runs using the [Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default).

To configured **Application Default Credentials** run:

```bash
gcloud auth application-default login
```

## Usage

To deploy the Blueprint in the Terraform Example Foundation, you will do updates
in sequence in the configurations of the steps used to the deploy the foundation.

### Directory layout and Terraform initialization

For these instructions we assume that:

- The foundation was deployed using Cloud Build.
- Every repository, excluding the policies repositories, should be on the `production` branch and `terraform init` should be executed in each one.
- The following layout should exists in your local environment since you will need to make changes in these steps.
If you do not have this layout, please checkout the source repositories for the foundation steps following this layout.

    ```text
    gcp-bootstrap
    gcp-environments
    gcp-networks
    gcp-org
    gcp-policies
    gcp-policies-app-infra
    gcp-projects
    ```

- Also checkout the [terraform-google-secured-data-warehouse-onprem-ingest](https://github.com/GoogleCloudPlatform/terraform-google-secured-data-warehouse-onprem-ingest) repository at the same level.

The final layout should look like this:

  ```text
  gcp-bootstrap
  gcp-environments
  gcp-networks
  gcp-org
  gcp-policies
  gcp-policies-app-infra
  gcp-projects
  terraform-google-secured-data-warehouse-onprem-ingest
  ```


### Update gcloud terraform vet policies

the first step is to update the `gcloud terraform vet` policies constraints to allow usage of the APIs needed by the Blueprint.
The constraints are located in the two policies repositories:

- `gcp-policies`
- `gcp-policies-app-infra`


The APIs to add are:

```yaml
    - "cloudfunctions.googleapis.com"
    - "datacatalog.googleapis.com"
    - "dlp.googleapis.com"
    - "bigquerydatapolicy.googleapis.com"
    - "vpcaccess.googleapis.com"
    - "run.googleapis.com"
    - "eventarc.googleapis.com"
    - "eventarcpublishing.googleapis.com"
    - "dataflow.googleapis.com"
```

1. The APIs should be included in the `services` list in the file [serviceusage_allow_basic_apis.yaml](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/policy-library/policies/constraints/serviceusage_allow_basic_apis.yaml#L30)
1. Update `gcp-policies/policies/constraints/serviceusage_allow_basic_apis.yaml` file in your policy repository (`gcp-policies`) for the CI/CD pipeline.
1. Commit changes in the `gcp-policies` repository and push the code.

1. Update `gcp-policies-app-infra/policies/constraints/serviceusage_allow_basic_apis.yaml` file in your policy repository (`gcp-policies-app-infra`) for the app infra pipeline.
1. Commit changes in the `gcp-policies-app-infra` repository and push the code.

### 0-bootstrap: Update terraform service account roles in bootstrap step

Grant and additional roles to the service account used in the 4-projects step.
This role is necessary for the creation of the Organization Policies needed by the Secured Data Warehouse Blueprint.
This is an organization level roles and must be granted at this step.

1. Update file `gcp-bootstrap/envs/shared/sa.tf` and add the role `roles/orgpolicy.policyAdmin` to the entry for the
project step service account (`proj`) in the `granular_sa_org_level_roles` map.

    ```hcl
        "proj" = distinct(concat([
          "roles/accesscontextmanager.policyAdmin",
          "roles/resourcemanager.organizationAdmin",
          "roles/serviceusage.serviceUsageConsumer",
          "roles/orgpolicy.policyAdmin",
        ], local.common_roles)),
    ```

1. Commit changes in the `gcp-bootstrap` repository and push the code to the `production` branch.
1. Check the build execution in `https://console.cloud.google.com/cloud-build/builds;region=<DEFAULT-REGION>?project=<CI/CD-PROJECT>`
1. The CI/CD project and the default region are outputs of the bootstrap step.

### 3-networks: Include environment step terraform service account in the restricted perimeter

Environment step terraform service account needs to be added to the restricted VPC-SC perimeter because in the following step you will grant an additional role to the network service account only in the restricted shared VPC project.

1. Update file `gcp-networks/modules/base_env/main.tf` in the `production` branch adding the Environment step terraform service account to the perimeter by updating the value for the variable `members` in the `restricted_shared_vpc` module:

    ```hcl
      members = distinct(concat([
        "serviceAccount:${local.networks_service_account}",
        "serviceAccount:${local.projects_service_account}",
        "serviceAccount:${local.organization_service_account}",
        "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.environment_step_terraform_service_account_email}",
      ], var.perimeter_additional_members))
    ```

1. Commit changes in the `gcp-networks` repository and push the code to the `production` branch.

### 2-environments: Enable additional APIs and Conditionally grant project IAM Admin role to the networks step terraform service account

1. Add the `"vpcaccess.googleapis.com"` API on the `activate_apis` list in `restricted_shared_vpc_host_project` module in file [modules/env_baseline/networking.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/2-environments/modules/env_baseline/networking.tf#LL68C1-L77C4)

```hcl
activate_apis = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "servicenetworking.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "vpcaccess.googleapis.com"
]
```

1. Conditionally grant to the networks step terraform service account the project IAM Admin role in the restricted shared project.
This is necessary for the serverless VPC access configuration.
This role is granted here and not in the bootstrap step to limit the scope of this role effect.

1. Update file `gcp-environments/modules/env_baseline/variables.tf` to create a toggle for the deploy of the Secured Data Warehouse.

    ```hcl
    variable "enable_sdw" {
      description = "Set to true to create the infrastructure needed the Secured Data Warehouse."
      type        = bool
      default     = false
    }
    ```

1. Update file `gcp-environments/envs/production/main.tf` to set the toggle to `true`:

    ```hcl
    module "env" {
      source = "../../modules/env_baseline"

      env                        = "production"
      environment_code           = "p"
      monitoring_workspace_users = var.monitoring_workspace_users
      remote_state_bucket        = var.remote_state_bucket

      enable_sdw = true
      ...
    }
    ```

1. Update file `gcp-environments/modules/env_baseline/iam.tf` and add the conditional grant of the role:

    ```hcl
    resource "google_project_iam_member" "iam_admin" {
      count = var.enable_sdw ? 1 : 0

      project = module.restricted_shared_vpc_host_project.project_id
      role    = "roles/resourcemanager.projectIamAdmin"
      member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email}"
    }
    ```

1. Wait for the `gcp-networks` build from the previous step to finish.
1. Commit changes in the `gcp-environments` repository and push the code to the `production` branch.


### 4-projects: Create a new workspace for the Secured Data Warehouse Onprem Ingest

Create a new workspace in the business unit 1 shared environment to isolate the resources that
will deployed in the Secured Data Warehouse Onprem Ingest that will be created in step 4.

1. Update file `gcp-projects/business_unit_1/shared/example_infra_pipeline.tf` to add a new repository in the locals:

    ```hcl
    locals {
      repo_names = ["bu1-example-app", "bu1-sdw-app"]
    }
    ```

1. Add the `bigquery.googleapis.com` and `"serviceusage.googleapis.com"` APIs to the list of `activate_apis` in the `app_infra_cloudbuild_project` module:

    ```hcl
      activate_apis = [
        "cloudbuild.googleapis.com",
        "sourcerepo.googleapis.com",
        "cloudkms.googleapis.com",
        "iam.googleapis.com",
        "artifactregistry.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "bigquery.googleapis.com",
        "serviceusage.googleapis.com"
      ]
    ```

1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.

### 4-projects: Create the projects for the Secured Data Warehouse Onprem Ingest in the production environment

1. Update file `gcp-projects/modules/base_env/variables.tf` to create a toggle for the deploy of the Secured Data Warehouse Onprem Ingest:

    ```hcl
    variable "enable_sdw" {
      description = "Set to true to create the infrastructure needed the Secured Data Warehouse Onprem Ingest."
      type        = bool
      default     = false
    }
    ```


1. Update file `gcp-projects/modules/base_env/outputs.tf` to add the outputs related to the new projects:

    ```hcl
    output "data_ingestion_project_id" {
      description = "The ID of the project in which Secured Data Warehouse Onprem Ingest data ingestion resources will be created."
      value       = var.enable_sdw ? module.data_ingestion_project[0].project_id : ""
    }

    output "data_ingestion_project_number" {
      description = "The project number in which Secured Data Warehouse Onprem Ingest data ingestion resources will be created."
      value       = var.enable_sdw ? module.data_ingestion_project[0].project_number : ""
    }

    output "data_governance_project_id" {
      description = "The ID of the project in which Secured Data Warehouse Onprem Ingest data governance resources will be created."
      value       = var.enable_sdw ? module.data_governance_project[0].project_id : ""
    }

    output "data_governance_project_number" {
      description = "The project number in which Secured Data Warehouse Onprem Ingest data governance resources will be created."
      value       = var.enable_sdw ? module.data_governance_project[0].project_number : ""
    }

    output "data_project_id" {
      description = "Project where Secured Data Warehouse Onprem Ingest datasets and tables are created."
      value       = var.enable_sdw ? module.data_project[0].project_id : ""
    }

    output "data_project_number" {
      description = "The project number where Secured Data Warehouse Onprem Ingest datasets and tables are created."
      value       = var.enable_sdw ? module.data_project[0].project_number : ""
    }

    output "default_region" {
      description = "Default region to create resources where applicable."
      value       = data.terraform_remote_state.bootstrap.outputs.common_config.default_region
    }
    ```

1. Update file `gcp-projects/business_unit_1/production/outputs.tf` to add the outputs related to the new projects:

    ```hcl
    output "data_ingestion_project_id" {
      description = "The ID of the project in which Secured Data Warehouse Onprem Ingest data ingestion resources will be created."
      value       = module.env.data_ingestion_project_id
    }

    output "data_ingestion_project_number" {
      description = "The project number in which Secured Data Warehouse Onprem Ingest data ingestion resources will be created."
      value       = module.env.data_ingestion_project_number
    }

    output "data_governance_project_id" {
      description = "The ID of the project in which Secured Data Warehouse Onprem Ingest data governance resources will be created."
      value       = module.env.data_governance_project_id
    }

    output "data_governance_project_number" {
      description = "The project number in which Secured Data Warehouse Onprem Ingest data governance resources will be created."
      value       = module.env.data_governance_project_number
    }

    output "data_project_id" {
      description = "Project where Secured Data Warehouse Onprem Ingest datasets and tables are created."
      value       = module.env.data_project_id
    }

    output "data_project_number" {
      description = "The project number where Secured Data Warehouse Onprem Ingest datasets and tables are created."
      value       = module.env.data_project_number
    }

    output "default_region" {
      description = "Default region to create resources where applicable."
      value       = module.env.default_region
    }
    ```

1. Create file `example_sdw_onprem_ingest_projects.tf` in folder `gcp-projects/modules/base_env` and copy the following code

    ```hcl
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

    module "data_governance_project" {
    source = "../single_project"
    count  = var.enable_sdw ? 1 : 0

    org_id          = local.org_id
    billing_account = local.billing_account
    folder_id       = local.env_folder_name
    environment     = var.env
    project_budget  = var.project_budget
    project_prefix  = local.project_prefix

    enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
    app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

    sa_roles = {
        "${var.business_code}-sdw-app" = [
        "roles/bigquery.jobUser",
        "roles/datacatalog.admin",
        "roles/cloudkms.admin",
        "roles/storage.admin",
        "roles/dlp.user",
        "roles/bigquery.admin",
        "roles/serviceusage.serviceUsageAdmin",
        "roles/dlp.inspectTemplatesEditor",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountUser",
        ]
    }

    activate_apis = [
        "cloudbuild.googleapis.com",
        "cloudfunctions.googleapis.com",
        "datacatalog.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "storage-api.googleapis.com",
        "serviceusage.googleapis.com",
        "iam.googleapis.com",
        "accesscontextmanager.googleapis.com",
        "cloudbilling.googleapis.com",
        "cloudkms.googleapis.com",
        "dlp.googleapis.com",
        "secretmanager.googleapis.com",
        "bigquery.googleapis.com",
        "bigquerydatapolicy.googleapis.com",
    ]

    # Metadata
    project_suffix    = "data-gov"
    application_name  = "${var.business_code}-data-gov"
    billing_code      = "1234"
    primary_contact   = "example@example.com"
    secondary_contact = "example2@example.com"
    business_code     = var.business_code
    }



    module "data_project" {
    source = "../single_project"
    count  = var.enable_sdw ? 1 : 0

    org_id          = local.org_id
    billing_account = local.billing_account
    folder_id       = local.env_folder_name
    environment     = var.env
    project_budget  = var.project_budget
    project_prefix  = local.project_prefix

    enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
    app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

    sa_roles = {
        "${var.business_code}-sdw-app" = [
        "roles/bigquery.jobUser",
        "roles/storage.admin",
        "roles/dlp.user",
        "roles/bigquery.admin",
        "roles/serviceusage.serviceUsageAdmin",
        "roles/dlp.inspectTemplatesEditor",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountUser",
        ]
    }

    activate_apis = [
        "cloudresourcemanager.googleapis.com",
        "storage-api.googleapis.com",
        "serviceusage.googleapis.com",
        "iam.googleapis.com",
        "bigquery.googleapis.com",
        "accesscontextmanager.googleapis.com",
        "cloudbilling.googleapis.com",
        "cloudkms.googleapis.com",
        "dataflow.googleapis.com",
        "dlp.googleapis.com",
        "datacatalog.googleapis.com",
        "dns.googleapis.com",
        "compute.googleapis.com",
        "cloudbuild.googleapis.com",
        "artifactregistry.googleapis.com",
        "dlp.googleapis.com",
    ]

    # Metadata
    project_suffix    = "data"
    application_name  = "${var.business_code}-data"
    billing_code      = "1234"
    primary_contact   = "example@example.com"
    secondary_contact = "example2@example.com"
    business_code     = var.business_code
    }

    module "data_ingestion_project" {
    source = "../single_project"
    count  = var.enable_sdw ? 1 : 0

    org_id                     = local.org_id
    billing_account            = local.billing_account
    folder_id                  = local.env_folder_name
    environment                = var.env
    vpc_type                   = "restricted"
    shared_vpc_host_project_id = local.restricted_host_project_id
    shared_vpc_subnets         = local.restricted_subnets_self_links
    project_budget             = var.project_budget
    project_prefix             = local.project_prefix

    enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
    app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

    sa_roles = {
        "${var.business_code}-sdw-app" = [
        "roles/bigquery.jobUser",
        "roles/storage.admin",
        "roles/dlp.user",
        "roles/bigquery.admin",
        "roles/serviceusage.serviceUsageAdmin",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountUser",
        "roles/resourcemanager.projectIamAdmin",
        "roles/pubsub.admin",
        ]
    }

    activate_apis = [
        "accesscontextmanager.googleapis.com",
        "vpcaccess.googleapis.com",
        "container.googleapis.com",
        "run.googleapis.com",
        "eventarc.googleapis.com",
        "cloudbuild.googleapis.com",
        "cloudfunctions.googleapis.com",
        "datacatalog.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "storage-api.googleapis.com",
        "serviceusage.googleapis.com",
        "iam.googleapis.com",
        "dns.googleapis.com",
        "pubsub.googleapis.com",
        "bigquery.googleapis.com",
        "cloudbilling.googleapis.com",
        "cloudkms.googleapis.com",
        "dataflow.googleapis.com",
        "dlp.googleapis.com",
        "cloudscheduler.googleapis.com",
        "cloudbuild.googleapis.com",
        "appengine.googleapis.com",
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
    ]

    vpc_service_control_attach_enabled = "true"
    vpc_service_control_perimeter_name = "accessPolicies/${local.access_context_manager_policy_id}/servicePerimeters/${local.perimeter_name}"
    vpc_service_control_sleep_duration = "60s"

    # Metadata
    project_suffix    = "data-ing"
    application_name  = "${var.business_code}-data-ing"
    billing_code      = "1234"
    primary_contact   = "example@example.com"
    secondary_contact = "example2@example.com"
    business_code     = var.business_code
    }


    module "dataflow_template_project" {
    source = "../single_project"
    count  = var.enable_sdw ? 1 : 0

    org_id          = local.org_id
    billing_account = local.billing_account
    folder_id       = local.env_folder_name
    environment     = var.env
    project_budget  = var.project_budget
    project_prefix  = local.project_prefix

    enable_cloudbuild_deploy            = local.enable_cloudbuild_deploy
    app_infra_pipeline_service_accounts = local.app_infra_pipeline_service_accounts

    sa_roles = {
        "${var.business_code}-sdw-app" = [
        "roles/storage.admin",
        "roles/storage.objectCreator",
        "roles/browser",
        "roles/artifactregistry.admin",
        "roles/iam.serviceAccountCreator",
        "roles/iam.serviceAccountDeleter",
        "roles/cloudbuild.builds.editor",
        ]
    }

    activate_apis = [
        "cloudresourcemanager.googleapis.com",
        "storage-api.googleapis.com",
        "serviceusage.googleapis.com",
        "iam.googleapis.com",
        "cloudbilling.googleapis.com",
        "artifactregistry.googleapis.com",
        "cloudbuild.googleapis.com",
        "compute.googleapis.com",
    ]

    # Metadata
    project_suffix    = "dataflow"
    application_name  = "${var.business_code}-dataflow"
    billing_code      = "1234"
    primary_contact   = "example@example.com"
    secondary_contact = "example2@example.com"
    business_code     = var.business_code
    }

    resource "google_project_iam_member" "iam_admin" {
    count = var.enable_sdw ? 1 : 0

    project = module.data_ingestion_project[0].project_id
    role    = "roles/vpcaccess.admin"
    member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email}"
    }
    ```

1. Update file `gcp-projects/business_unit_1/production/main.tf` to set the toggle to `true`:

    ```hcl
    module "env" {
      source = "../../modules/base_env"

      env                       = "production"
      business_code             = "bu1"
      business_unit             = "business_unit_1"
      remote_state_bucket       = var.remote_state_bucket
      location_kms              = var.location_kms
      location_gcs              = var.location_gcs
      peering_module_depends_on = var.peering_module_depends_on

      enable_sdw = true
    }
    ```

1. Wait for the `gcp-projects` build from the previous step to finish.
1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.


### 3-networks: Deploy the serverless connector and add new workspace service account to the restricted perimeter

1. Wait for the `gcp-projects` build from the previous step to finish.ls
1. Get the new workspace service account to the restricted perimeter:

    ```bash
    terraform -chdir="gcp-projects/business_unit_1/shared" init
    export app_infra_sa=$(terraform -chdir="gcp-projects/business_unit_1/shared" output -json terraform_service_accounts | jq '."bu1-sdw-app"' --raw-output)
    echo "APP_INFRA_SA_EMAIL = ${app_infra_sa}"
    ```

1. Update file `gcp-networks/envs/production/main.tf` replace the `perimeter_additional_members` line adding the app infra service account email from the previous step:

    ```hcl
    perimeter_additional_members          = concat(var.perimeter_additional_members,["serviceAccount:APP_INFRA_SA_EMAIL"])
    ```

1. Update file `gcp-networks/modules/base_env/variables.tf` to create a toggle for the deploy of the Secured Data Warehouse:

    ```hcl
    variable "enable_sdw" {
      description = "Set to true to create the infrastructure needed the Secured Data Warehouse."
      type        = bool
      default     = false
    }
    ```

1. Update file `gcp-networks/modules/base_env/outputs.tf` to add the `restricted_serverless_network_connector_id` output:

  ```hcl
      output "restricted_serverless_network_connector_id" {
        description = "VPC serverless connector ID for the restricted network."
        value       = var.enable_sdw ? module.serverless_connector[0].connector_id : ""
      }
  ```

1. Update file `gcp-networks/envs/production/outputs.tf` to add the `restricted_serverless_network_connector_id` output:

  ```hcl
      output "restricted_serverless_network_connector_id" {
        description = "VPC serverless connector ID for the restricted network."
        value       = module.base_env.restricted_serverless_network_connector_id
      }
  ```

1. Update file `gcp-networks/envs/production/main.tf` to set the toggle to `true`:

    ```hcl
    module "base_env" {
      source = "../../modules/base_env"

      env                                   = local.env
      environment_code                      = local.environment_code
      access_context_manager_policy_id      = var.access_context_manager_policy_id

    ...

      enable_sdw = true
    }
    ```

1. Create file `example_sdw_serverless_connector.tf` in folder `gcp-networks/modules/base_env` and copy the following code:

    ```hcl
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

    locals {
    default_region = data.terraform_remote_state.bootstrap.outputs.common_config.default_region
    // data ingestion project info
    data_ingestion_project_id = "DATA_INGESTION_PROJECT_ID"
    }

    resource "google_project_service_identity" "serverless_sa" {
    provider = google-beta
    count    = var.enable_sdw ? 1 : 0

    project = local.data_ingestion_project_id
    service = "cloudfunctions.googleapis.com"
    }

    module "serverless_connector" {
    source  = "GoogleCloudPlatform/cloud-run/google//modules/secure-serverless-net"
    version = "~> 0.9"
    count   = var.enable_sdw ? 1 : 0

    connector_name            = "serverless-connector"
    subnet_name               = "sb-p-connector-${local.default_region}"
    location                  = local.default_region
    vpc_project_id            = local.restricted_project_id
    serverless_project_id     = local.data_ingestion_project_id
    shared_vpc_name           = module.restricted_shared_vpc.network_name
    ip_cidr_range             = "10.4.0.0/28"
    resource_names_suffix     = "sdw"
    create_subnet             = true
    connector_on_host_project = false
    enable_load_balancer_fw   = false

    serverless_service_identity_email = google_project_service_identity.serverless_sa[0].email
    }
    ```

1. Replace the data ingestion project id:

    ```bash
    terraform -chdir="gcp-projects/business_unit_1/production" init
    export data_ingestion_project_id=$(terraform -chdir="gcp-projects/business_unit_1/production" output -raw data_ingestion_project_id)
    echo "data_ingestion_project_id = ${data_ingestion_project_id}"
    sed -i "s/DATA_INGESTION_PROJECT_ID/${data_ingestion_project_id}/" "gcp-networks/modules/base_env/example_sdw_serverless_connector.tf"
    ```

1. Update the `target_tags` property in resource `allow_restricted_api_egress` in the file [gcp-networks/modules/restricted_shared_vpc/firewall.tf](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/3-networks-dual-svpc/modules/restricted_shared_vpc/firewall.tf#LL69C1-L69C38) in the module `restricted_shared_vpc` adding the tag `"vpc-connector"` to the firewall rule that allows Google private API access.

  ```hcl
  target_tags = ["allow-google-apis", "vpc-connector"]
  ```

1. Fix the Rule [priority](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v3.0.0/3-networks-dual-svpc/modules/restricted_shared_vpc/firewall.tf#LL50C1-L50C20) on the same firewall resource to be `65430`

  ```hcl
  priority  = 65430
  ```

1. Commit changes in the `gcp-networks` repository and push the code to the `production` branch.

### 4-projects: Deploy the Secured Data Warehouse

1. Update file `gcp-projects/modules/base_env/variables.tf` to create a variables for the perimeter users and security groups:

    ```hcl
    variable "sdw_perimeter_additional_members" {
      description = "The list of additional members to be added to the Secured Data Warehouse perimeter access level members list."
      type        = list(string)
      default     = []
    }

    variable "security_administrator_group" {
      description = "Google Cloud IAM group that administers security configurations in the organization(org policies, KMS, VPC service perimeter)."
      type        = string
      default     = ""
    }

    variable "network_administrator_group" {
      description = "Google Cloud IAM group that reviews network configuration. Typically, this includes members of the networking team."
      type        = string
      default     = ""
    }

    variable "security_analyst_group" {
      description = "Google Cloud IAM group that monitors and responds to security incidents."
      type        = string
      default     = ""
    }

    variable "data_analyst_group" {
      description = "Google Cloud IAM group that analyzes the data in the warehouse."
      type        = string
      default     = ""
    }

    variable "data_engineer_group" {
      description = "Google Cloud IAM group that sets up and maintains the data pipeline and warehouse."
      type        = string
      default     = ""
    }

    variable "plaintext_reader_group" {
      description = "Google Cloud IAM group that analyzes plaintext reader."
      type        = string
      default     = ""
    }

    variable "encrypted_data_reader_group" {
      description = "Google Cloud IAM group that analyzes encrypted data."
      type        = string
      default     = ""
    }
    ```

1. Update file `gcp-projects/modules/base_env/outputs.tf` to add the outputs related to the new projects:

    ```hcl
    output "data_ingestion_bucket_name" {
      description = "The data ingestion bucket name."
      value       = var.enable_sdw ? module.secured_data_warehouse_onprem_ingest[0].data_ingestion_bucket_name : ""
    }

    output "cmek_data_ingestion_crypto_key" {
      description = "Data ingestion crypto key."
      value       = var.enable_sdw ? module.secured_data_warehouse_onprem_ingest[0].cmek_data_ingestion_crypto_key : ""
    }

    output "plaintext_reader_group" {
      description = "Google Cloud IAM group that analyzes plaintext reader."
      value       = var.plaintext_reader_group
    }

    output "encrypted_data_reader_group" {
      description = "Google Cloud IAM group that analyzes encrypted data."
      value       = var.encrypted_data_reader_group
    }

    output "data_analyst_group" {
      description = "Google Cloud IAM group that analyzes the data in the warehouse."
      value       = var.data_analyst_group
    }

    output "restricted_serverless_network_connector_id" {
      description = "VPC serverless connector ID for the restricted network."
      value       = local.restricted_serverless_network_connector_id
    }
    ```

1. Update file `gcp-projects/business_unit_1/production/outputs.tf` to add the outputs related to the new projects:

    ```hcl
    output "data_ingestion_bucket_name" {
      description = "The data ingestion bucket name."
      value       = module.env.data_ingestion_bucket_name
    }

    output "cmek_data_ingestion_crypto_key" {
      description = "Data ingestion crypto key."
      value       = module.env.cmek_data_ingestion_crypto_key
    }

    output "plaintext_reader_group" {
      description = "Google Cloud IAM group that analyzes plaintext reader."
      value       = module.env.plaintext_reader_group
    }

    output "encrypted_data_reader_group" {
      description = "Google Cloud IAM group that analyzes encrypted data."
      value       = module.env.encrypted_data_reader_group
    }

    output "data_analyst_group" {
      description = "Google Cloud IAM group that analyzes the data in the warehouse."
      value       = module.env.data_analyst_group
    }

    output "restricted_serverless_network_connector_id" {
      description = "VPC serverless connector ID for the restricted network."
      value       = module.env.restricted_serverless_network_connector_id
    }
    ```

1. Create file `/gcp-projects/modules/base_env/example_sdw_secured_data_warehouse_onprem_ingest.tf` and copy the following content:

    ```hcl
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

    locals {
    sdw_app_infra_sa             = var.enable_sdw ? local.app_infra_pipeline_service_accounts["${var.business_code}-sdw-app"] : ""
    perimeter_additional_members = concat(var.sdw_perimeter_additional_members,["serviceAccount:${local.sdw_app_infra_sa}"])

    restricted_serverless_network_connector_id = try(data.terraform_remote_state.network_env.outputs.restricted_serverless_network_connector_id, "")

    location           = data.terraform_remote_state.bootstrap.outputs.common_config.default_region
    dataset_id         = "data_dataset"
    dlp_output_dataset = "dlp_scanner_output"
    }

    module "secured_data_warehouse_onprem_ingest" {
    source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google"
    version = "~> 0.1"
    count   = var.enable_sdw ? 1 : 0

    org_id                           = local.org_id
    labels                           = { environment = "dev" }
    data_governance_project_id       = module.data_governance_project[0].project_id
    data_governance_project_number   = module.data_governance_project[0].project_number
    data_project_id                  = module.data_project[0].project_id
    data_project_number              = module.data_project[0].project_number
    data_ingestion_perimeter         = local.perimeter_name
    data_ingestion_project_id        = module.data_ingestion_project[0].project_id
    data_ingestion_project_number    = module.data_ingestion_project[0].project_number
    sdx_project_number               = module.dataflow_template_project[0].project_number
    terraform_service_account        = data.terraform_remote_state.bootstrap.outputs.projects_step_terraform_service_account_email
    access_context_manager_policy_id = local.access_context_manager_policy_id
    bucket_name                      = "standalone-data-ing"
    pubsub_resource_location         = local.location
    location                         = local.location
    trusted_locations                = ["us-locations"]
    dataset_id                       = local.dataset_id
    cmek_keyring_name                = "standalone-data-ing"

    add_project_to_data_ingestion_perimeter = false

    // provide additional information
    delete_contents_on_destroy   = true
    perimeter_additional_members = local.perimeter_additional_members
    data_engineer_group          = var.data_engineer_group
    data_analyst_group           = var.data_analyst_group
    security_analyst_group       = var.security_analyst_group
    network_administrator_group  = var.network_administrator_group
    security_administrator_group = var.security_administrator_group
    encrypted_data_reader_group  = var.encrypted_data_reader_group
    plaintext_reader_group       = var.plaintext_reader_group

    // Set the enable_bigquery_read_roles_in_data_ingestion to true, it will grant to the dataflow controller
    // service account created in the data ingestion project the necessary roles to read from a bigquery table.
    enable_bigquery_read_roles_in_data_ingestion = true

    depends_on = [
        module.data_governance_project,
        module.data_project,
        module.data_ingestion_project,
        module.dataflow_template_project,
    ]
    }
    ```

1. Update file `gcp-projects/business_unit_1/production/main.tf` to set values for the perimeter users and security groups:

    ```hcl
    module "env" {
      source = "../../modules/base_env"

      env                       = "production"
      business_code             = "bu1"
      business_unit             = "business_unit_1"
      remote_state_bucket       = var.remote_state_bucket
      location_kms              = var.location_kms
      location_gcs              = var.location_gcs
      peering_module_depends_on = var.peering_module_depends_on

      enable_sdw = true

      sdw_perimeter_additional_members = ["user:YOUR-USER-EMAIL@example.com"]

      data_engineer_group          = "DATA_ENGINEER_GROUP@EXAMPLE.COM"
      data_analyst_group           = "DATA_ANALYST_GROUP@EXAMPLE.COM"
      security_analyst_group       = "SECURITY_ANALYST_GROUP@EXAMPLE.COM"
      network_administrator_group  = "NETWORK_ADMINISTRATOR_GROUP@EXAMPLE.COM"
      security_administrator_group = "SECURITY_ADMINISTRATOR_GROUP@EXAMPLE.COM"
      encrypted_data_reader_group  = "ENCRYPTED_DATA_READER_GROUP@EXAMPLE.COM"
      plaintext_reader_group       = "PLAINTEXT_READER_GROUP@EXAMPLE.COM"
    }
    ```

1. Commit changes in the `gcp-projects` repository and push the code to the `production` branch.


### 5-app-infra: Deploy encrypted table

1. Clone the new repo created in step 4-projects/shared:

    ```bash
    terraform -chdir="gcp-projects/business_unit_1/shared/" init
    export INFRA_PIPELINE_PROJECT_ID=$(terraform -chdir="gcp-projects/business_unit_1/shared/" output -raw cloudbuild_project_id)
    echo ${INFRA_PIPELINE_PROJECT_ID}

    gcloud source repos clone bu1-sdw-app --project=${INFRA_PIPELINE_PROJECT_ID}
    ```

1. Copy the Cloud Build setup and the shared configuration folder:

    ```bash
    cd bu1-sdw-app
    git checkout -b production

    export sdw_path="../terraform-google-secured-data-warehouse-onprem-ingest/docs/foundation_deploy/bu1-sdw-app/business_unit_1"

    mkdir -p business_unit_1/shared business_unit_1/production

    cp ../terraform-example-foundation/build/cloudbuild-tf-* .
    cp ../terraform-example-foundation/build/tf-wrapper.sh .
    chmod 755 ./tf-wrapper.sh

    cp -RT "${sdw_path}/shared/" "./business_unit_1/shared/"
    mv ./business_unit_1/shared/terraform.example.tfvars ./business_unit_1/shared/terraform.tfvars
    ```

1. Update terraform backend and remote state configuration:

    ```bash
    backend_bucket=$(terraform -chdir="../gcp-projects/business_unit_1/shared" output -json state_buckets | jq '."bu1-sdw-app"' --raw-output)
    echo "backend_bucket = ${backend_bucket}"

    sed -i "s/UPDATE_APP_INFRA_SDW_BUCKET/${backend_bucket}/" ./business_unit_1/shared/backend.tf

    export remote_state_bucket=$(terraform -chdir="../gcp-bootstrap/envs/shared" output -raw projects_gcs_bucket_tfstate)
    echo "remote_state_bucket = ${remote_state_bucket}"

    sed -i "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./business_unit_1/shared/terraform.tfvars
    ```

1. Commit changes in the `bu1-sdw-app` repository and push the code to the `production` branch.
1. Wait for the end of Cloud Build build.
1. Check the build execution in `https://console.cloud.google.com/cloud-build/builds;region=<DEFAULT-REGION>?project=<INFRA_PIPELINE_PROJECT_ID>`.
1. Load the state in local folder:

    ```bash
    terraform -chdir="./business_unit_1/shared/" init
    ```

1. Copy the production configuration folder with the encrypted table creation:

    ```bash
    export sdw_path="../terraform-google-secured-data-warehouse-onprem-ingest/docs/foundation_deploy/bu1-sdw-app/business_unit_1"
    cp -RT "${sdw_path}/production/" "./business_unit_1/production/"
    mv ./business_unit_1/production/terraform.example.tfvars ./business_unit_1/production/terraform.tfvars
    mv ./business_unit_1/production/example_sdw_encrypted_table.tf.example ./business_unit_1/production/example_sdw_encrypted_table.tf
    mv ./business_unit_1/production/variables.tf.example ./business_unit_1/production/variables.tf

    export extra_sdw_path="../terraform-google-secured-data-warehouse-onprem-ingest/examples/standalone"

    mkdir -p ./business_unit_1/production/assets ./business_unit_1/production/helpers ./business_unit_1/production/templates
    cp -RT "${extra_sdw_path}/assets/" ./business_unit_1/production/assets/
    cp -RT "${extra_sdw_path}/helpers/" ./business_unit_1/production/helpers/
    cp -RT "${extra_sdw_path}/templates/" ./business_unit_1/production/templates/
    ```

1. Update terraform backend and remote state configuration:

    ```bash
    backend_bucket=$(terraform -chdir="../gcp-projects/business_unit_1/shared/" output -json state_buckets | jq '."bu1-sdw-app"' --raw-output)
    echo "backend_bucket = ${backend_bucket}"

    sed -i "s/UPDATE_APP_INFRA_SDW_BUCKET/${backend_bucket}/" ./business_unit_1/production/backend.tf
    sed -i "s/UPDATE_APP_INFRA_SDW_BUCKET/${backend_bucket}/" ./business_unit_1/production/terraform.tfvars

    export remote_state_bucket=$(terraform -chdir="../gcp-bootstrap/envs/shared" output -raw projects_gcs_bucket_tfstate)
    echo "remote_state_bucket = ${remote_state_bucket}"

    sed -i "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./business_unit_1/production/terraform.tfvars
    ```

1. Create an encryption key using tinkey and use the key to encrypt a file with sample credit card data:

    ```bash
    cd ./business_unit_1/production/
    export basepath=$(pwd)
    export kek_wrapping_key=$(terraform -chdir="../shared/" output -raw kek_wrapping_key)
    echo "kek_wrapping_key = ${kek_wrapping_key}"

    # grant temporary access to the kek_wrapping_key
    project_sa=$(terraform -chdir="../../../gcp-bootstrap/envs/shared" output -raw projects_step_terraform_service_account_email)
    echo "project_sa = ${project_sa}"

    member="user:$(gcloud auth list --filter="status=ACTIVE" --format="value(account)")"
    echo "member = ${member}"

    gcloud kms keys add-iam-policy-binding ${kek_wrapping_key} \
     --member="${member}" \
     --role=roles/cloudkms.cryptoOperator \
     --impersonate-service-account="${project_sa}"

    tinkey create-keyset \
    --key-template AES256_GCM \
    --out-format json \
    --out ./keyset.json \
    --master-key-uri "gcp-kms://${kek_wrapping_key}"

    cd ./helpers/csv-encrypter/

    go run ./csv-encrypter.go \
      --in "${basepath}/assets/cc_10000_records.csv" \
      --out "${basepath}/encrypted.csv" \
      --fields "Card_Number,Card_Holders_Name,CVV_CVV2,Expiry_Date,Card_PIN,Credit_Limit" \
      --keyset "${basepath}/keyset.json" \
      --master-key-uri "gcp-kms://${kek_wrapping_key}"

    # remove temporary access to the kek_wrapping_key
    gcloud kms keys remove-iam-policy-binding ${kek_wrapping_key} \
     --member="${member}" \
    --role=roles/cloudkms.cryptoOperator \
    --impersonate-service-account="${project_sa}"

    cd ../../../..
    ```

1. Commit changes in the `bu1-sdw-app` repository and push the code to the `production` branch.
