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
