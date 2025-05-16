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

/**
* common variables
*/
variable "org_id" {
  description = "GCP Organization ID."
  type        = string
}

variable "location" {
  description = "The location for the KMS Customer Managed Encryption Keys, Cloud Storage Buckets, and Bigquery datasets. This location can be a multi-region."
  type        = string
  default     = "us-east4"
}

variable "labels" {
  description = "(Optional) Labels attached to Data Warehouse resources."
  type        = map(string)
  default     = {}
}

variable "terraform_service_account" {
  description = "The email address of the service account that will run the Terraform code."
  type        = string
}

variable "delete_contents_on_destroy" {
  description = "(Optional) If set to true, delete all the tables in the dataset when destroying the resource; otherwise, destroying the resource will fail if tables are present."
  type        = bool
  default     = false
}

/**
* Projects variables
*/
variable "data_ingestion_project_id" {
  description = "The ID of the project in which the data ingestion resources will be created."
  type        = string
}

variable "data_governance_project_id" {
  description = "The ID of the project in which the data governance resources will be created."
  type        = string
}

variable "data_project_id" {
  description = "Project where the datasets and tables are created."
  type        = string
}

variable "data_ingestion_project_number" {
  description = "The project number in which the data ingestion resources will be created."
  type        = string
}

variable "data_governance_project_number" {
  description = "The project number in which the data governance resources will be created."
  type        = string
}

variable "data_project_number" {
  description = "The project number where the datasets and tables are created."
  type        = string
}

variable "sdx_project_number" {
  description = "The Project Number to configure Secure data exchange with egress rule for dataflow templates. Required if using a dataflow job template from a private storage bucket outside of the perimeter."
  type        = string
  default     = ""
}

variable "add_project_to_data_ingestion_perimeter" {
  description = "If the data ingestion project should be added to the data ingestion perimeter."
  type        = bool
  default     = true
}

variable "add_project_to_data_governance_perimeter" {
  description = "If the data governance project should be added to the data governance perimeter."
  type        = bool
  default     = true
}

variable "add_project_to_data_perimeter" {
  description = "If the data project should be added to the data perimeter."
  type        = bool
  default     = true
}

variable "remove_owner_role" {
  description = "(Optional) If set to true, remove all owner roles in all projects in case it has been found in some project."
  type        = bool
  default     = false
}

/**
* IAM variables
*/
variable "security_administrator_group" {
  description = "Google Cloud IAM group that administers security configurations in the organization(org policies, KMS, VPC service perimeter)."
  type        = string
}

variable "network_administrator_group" {
  description = "Google Cloud IAM group that reviews network configuration. Typically, this includes members of the networking team."
  type        = string
}

variable "security_analyst_group" {
  description = "Google Cloud IAM group that monitors and responds to security incidents."
  type        = string
}

variable "data_analyst_group" {
  description = "Google Cloud IAM group that analyzes the data in the warehouse."
  type        = string
}

variable "data_engineer_group" {
  description = "Google Cloud IAM group that sets up and maintains the data pipeline and warehouse."
  type        = string
}

variable "plaintext_reader_group" {
  description = "Google Cloud IAM group that analyzes plaintext reader."
  type        = string
}

variable "encrypted_data_reader_group" {
  description = "Google Cloud IAM group that analyzes encrypted data."
  type        = string
}

variable "data_ingestion_dataflow_deployer_identities" {
  description = "List of members in the standard GCP form: user:{email}, serviceAccount:{email} that will deploy Dataflow jobs in the Data Ingestion project. These identities will be added to the VPC-SC secure data exchange egress rules."
  type        = list(string)
  default     = []
}

variable "database_type" {
  description = "Type of database where the data will be persisted. Available values are: \"POSTGRES\", \"BIG_QUERY\"."
  type        = string
  default     = "BIG_QUERY"

  validation {
    condition     = contains(["BIG_QUERY", "POSTGRESQL"], var.database_type)
    error_message = "Allowed values are: \"BIG_QUERY\", \"POSTGRESQL\"."
  }
}

/**
* BigQuery variables
*/
variable "dataset_id" {
  description = "Unique ID for the dataset being provisioned."
  type        = string
  default     = "data_dataset"
}

variable "dataset_name" {
  description = "Friendly name for the dataset being provisioned."
  type        = string
  default     = "Data dataset"
}

variable "dataset_description" {
  description = "Dataset description."
  type        = string
  default     = "Data dataset"
}

variable "dataset_default_table_expiration_ms" {
  description = "TTL of tables using the dataset in MS. The default value is null."
  type        = number
  default     = null
}

variable "dlp_output_dataset" {
  description = "Unique ID for the dataset being provisioned to host Cloud Data Loss Prevention (DLP) BigQuery scan results."
  type        = string
  default     = "dlp_scanner_output"
}

/**
* KMS variables
*/
variable "cmek_keyring_name" {
  description = "The Keyring prefix name for the KMS Customer Managed Encryption Keys being provisioned."
  type        = string
}

variable "key_rotation_period_seconds" {
  description = "Rotation period for keys. The default value is 30 days."
  type        = string
  default     = "2592000s"
}

variable "kms_key_protection_level" {
  description = "The protection level to use when creating a key. Possible values: [\"SOFTWARE\", \"HSM\"]"
  type        = string
  default     = "HSM"
}

/**
* VPC-SC variables
*/
variable "access_context_manager_policy_id" {
  description = "The id of the default Access Context Manager policy. Can be obtained by running `gcloud access-context-manager policies list --organization YOUR-ORGANIZATION_ID --format=\"value(name)\"`."
  type        = string
  default     = ""
}

variable "perimeter_additional_members" {
  description = "The list additional members to be added on perimeter access. Prefix user: (user:email@email.com) or serviceAccount: (serviceAccount:my-service-account@email.com) is required."
  type        = list(string)
  default     = []
}

variable "data_ingestion_ingress_policies" {
  description = "A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "data_ingestion_egress_policies" {
  description = "A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "data_governance_ingress_policies" {
  description = "A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "data_governance_egress_policies" {
  description = "A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data Governance perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "data_ingress_policies" {
  description = "A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "data_egress_policies" {
  description = "A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data perimeter, each list object has a `from` and `to` value that describes egress_from and egress_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module."
  type = list(object({
    from = any
    to   = any
  }))
  default = []
}

variable "custom_restricted_services" {
  description = "The list of custom Google services to be protected by the VPC-SC perimeters."
  type        = list(string)
  default     = []
}

variable "data_ingestion_perimeter" {
  description = "Existing data ingestion perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module."
  type        = string
  default     = ""
}

variable "data_governance_perimeter" {
  description = "Existing data governance perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module."
  type        = string
  default     = ""
}

variable "data_perimeter" {
  description = "Existing data perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module."
  type        = string
  default     = ""
}

/**
* Organization Policies variables
*/
variable "trusted_locations" {
  description = "This is a list of trusted regions where location-based GCP resources can be created."
  type        = list(string)
  default     = ["us-locations"]
}

variable "trusted_shared_vpc_subnetworks" {
  description = "The URI of the trusted Shared VPC subnetworks where resources will be allowed to be deployed. Used by 'Restrict Shared VPC Subnetworks' Organization Policy. Format 'projects/PROJECT_ID/regions/REGION/subnetworks/SUBNETWORK-NAME'."
  type        = list(string)
  default     = []
}

variable "domains_to_allow" {
  description = "The list of domains to allow users from in IAM. Used by Domain Restricted Sharing Organization Policy. Must include the domain of the organization you are deploying the blueprint. To add other domains you must also grant access to these domains to the terraform service account used in the deploy."
  type        = list(string)
  default     = []
}

variable "access_level_ip_subnetworks" {
  description = "Condition - A list of CIDR block IP subnetwork specification. May be IPv4 or IPv6. Note that for a CIDR IP address block, the specified IP address portion must be properly truncated (that is, all the host bits must be zero) or the input is considered malformed. For example, \"192.0.2.0/24\" is accepted but \"192.0.2.1/24\" is not. Similarly, for IPv6, \"2001:db8::/32\" is accepted whereas \"2001:db8::1/32\" is not. The originating IP of a request must be in one of the listed subnets in order for this Condition to be true. If empty, all IP addresses are allowed."
  type        = list(string)
  default     = []
}

/**
*Data Ingestion variables
*/
variable "pubsub_resource_location" {
  description = "The location in which the messages published to Pub/Sub will be persisted. This location cannot be a multi-region."
  type        = string
  default     = "us-east4"
}

variable "bucket_name" {
  description = "The name of the bucket being provisioned."
  type        = string

  validation {
    condition     = length(var.bucket_name) < 20
    error_message = "The bucket_name must contain less than 20 characters. This ensures the name can be prefixed with the project-id and suffixed with 8 random characters."
  }
}

variable "bucket_class" {
  description = "The storage class for the bucket being provisioned."
  type        = string
  default     = "STANDARD"
}

variable "bucket_lifecycle_rules" {
  description = "List of lifecycle rules to configure. Format is the same as described in provider documentation https://www.terraform.io/docs/providers/google/r/storage_bucket.html#lifecycle_rule except condition.matches_storage_class should be a comma delimited string."
  type = set(object({
    action    = any
    condition = any
  }))
  default = [{
    action = {
      type = "Delete"
    }
    condition = {
      age                   = 30
      with_state            = "ANY"
      matches_storage_class = "STANDARD"
    }
  }]
}

variable "enable_bigquery_read_roles_in_data_ingestion" {
  description = "(Optional) If set to true, it will grant to the dataflow controller service account created in the data ingestion project the necessary roles to read from a bigquery table."
  type        = bool
  default     = false
}

/**
*PostgreSQL variables
*/

variable "postgresql" {
  type = object(
    {
      version                     = string
      maintenance_version         = optional(string, null)
      deletion_protection_enabled = optional(bool, true)
      machine_type                = string
    }
  )
  nullable = true
  default  = null
}
