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

output "data_ingestion_project_id" {
  description = "Data ingestion project ID."
  value       = module.data_ingestion_project.project_id

  depends_on = [
    module.data_ingestion_project
  ]
}

output "data_governance_project_id" {
  description = "Data governance project ID"
  value       = module.data_governance_project.project_id

  depends_on = [
    module.data_governance_project,
    google_project_service_identity.data_governance_service_agents,
  ]
}

output "data_project_id" {
  description = "Data project ID."
  value       = module.data_project.project_id

  depends_on = [
    module.data_project
  ]
}

output "data_ingestion_project_number" {
  description = "Data ingestion project number."
  value       = module.data_ingestion_project.project_number

  depends_on = [
    module.data_ingestion_project
  ]
}

output "data_governance_project_number" {
  description = "Data governance project number"
  value       = module.data_governance_project.project_number

  depends_on = [
    module.data_governance_project
  ]
}

output "data_project_number" {
  description = "Data project number."
  value       = module.data_project.project_number

  depends_on = [
    module.data_project
  ]
}

output "data_ingestion_network_name" {
  description = "The name of the data ingestion VPC being created."
  value       = module.network.network_name
}

output "data_ingestion_network_self_link" {
  description = "The URI of the data ingestion VPC being created."
  value       = module.network.network_self_link
}

output "data_ingestion_subnets_self_link" {
  description = "The self-links of data ingestion subnets being created."
  value       = module.network.subnets_self_links[0]
}

output "data_ingestion_subnet_name" {
  description = "The name of the data ingestion subnet being created."
  value       = module.network.subnets_names[0]
}

output "data_ingestion_subnet_id" {
  description = "The id of the data ingestion subnet being created."
  value       = module.network.subnets_ids[0]
}
