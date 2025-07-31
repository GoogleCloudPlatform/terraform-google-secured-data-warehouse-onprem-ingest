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

output "instance_name" {
  description = "PostgreSQL instance name."
  value       = module.postgresql.instance_name
}

output "instance_ip_address" {
  description = "PostgreSQL master instance ip address."
  value       = module.postgresql.instance_ip_address
}

output "user_name" {
  description = "PostgreSQL root user name."
  value       = local.user_name
}

output "user_password" {
  description = "PostgreSQL root user password."
  sensitive   = true
  value       = module.postgresql.generated_user_password
}
