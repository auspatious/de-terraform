output "db_instance_identifier" {
  description = "RDS database instance identifier"
  value       = module.resources.db_instance_identifier
}

output "public_bucket_name" {
  description = "S3 Public bucket name"
  value = module.resources.public_bucket_name
}