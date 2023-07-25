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

variable "project_id" {
  description = "The project id where the organization policies will be enforced."
  type        = string
}

variable "trusted_shared_vpc_subnetworks" {
  description = "The URI of the trusted Shared VPC subnetworks where resources will be allowed to be deployed. Used by 'Restrict Shared VPC Subnetworks' Organization Policy. Format 'projects/PROJECT_ID/regions/REGION/subnetworks/SUBNETWORK-NAME'."
  type        = list(string)
  default     = []
}

variable "trusted_locations" {
  description = "The list of trusted locations where location-based Google Cloud resources can be created. Used by 'Google Cloud Platform - Resource Location Restriction' Organization Policy. Values can be multi-regions, regions, and value groups. See https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations"
  type        = list(string)
  default     = ["us-locations", "eu-locations"]
}

variable "domains_to_allow" {
  description = "The list of domains to allow users identities to be added to IAM policies. Used by 'Domain Restricted Sharing' Organization Policy. Must include the domain of the organization you are deploying the blueprint. To add other domains you must also grant access to these domains to the terraform service account used in the deploy. See https://cloud.google.com/resource-manager/docs/organization-policy/restricting-domains"
  type        = list(string)
}

variable "restricted_non_cmek_services" {
  description = "Defines which services require Customer-Managed Encryption Keys (CMEK). Used by the 'Restrict which services may create resources without CMEK' Organization Policy."
  type        = list(string)
  default     = []
}
