# List of bucket names
variable "write_bucket_names" {
  type        = list(string)
  description = "List of bucket names to give write permissions to (they get read too)"
}

variable "read_bucket_names" {
  type        = list(string)
  description = "List of bucket names to give read only permissions to (optional)"
  default     = []
}

# Write path
variable "write_path" {
  type        = string
  description = "Path to limit writing to in the bucket (optional). Must be a valid prefix like 'wofs/."
  default     = ""
}

# Service account namespace
variable "namespace" {
  type        = string
  description = "Service account namespace"
}

# Name to use for the service account and roles
variable "name" {
  type        = string
  description = "Name to use for the service account and roles. Use kebab-case."
}

# OIDC Provider ARN
variable "oidc_provider_arn" {
  type        = string
  description = "OIDC Provider ARN"
}

# Create service account flag
variable "create_sa" {
  type        = bool
  description = "Create the service account"
  default     = true
}

variable "max_session_duration" {
  type        = number
  description = "The maximum session duration for the role"
  default     = 10800
}
