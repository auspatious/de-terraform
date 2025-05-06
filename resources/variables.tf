variable "environment" {
  type        = string
  description = "Environments, i.e., test, stage, prod"
}

variable "aws-region" {
  type        = string
  description = "The aws region"
}

variable "eks-version" {
  type        = string
  description = "The version of Kubernetes for this environment"
}

variable "coredns-version" {
  type        = string
  description = "The version of CoreDNS for this environment"
}

variable "vpc-cni-version" {
  type        = string
  description = "The version of VPC CNI for this environment"
}

variable "kube-proxy-version" {
  type        = string
  description = "The version of kube-proxy for this environment"
}

variable "subdomain" {
  type        = string
  description = "The subdomain for the environment"
}

# Temporary while this is different to the subdomain
variable "jhub_subdomain" {
  type        = string
  description = "The subdomain for the JupyterHub"
}

variable "auth0-tenant" {
  type        = string
  description = "The Auth0 tenant URL"
}

variable "sso-admin-role-arn" {
  type        = string
  description = "The ARN of SSO Admin group"
}

variable "db-instance-class" {
  type        = string
  description = "The instance class for the database"
  default     = "db.r6g.large"
}

locals {
  # Kubernetes config
  cluster_name = "org-${var.environment}-eks"
  # Tags to use on everything
  tags = {
    "stack-name" = "org-${var.environment}"
    "project"    = "Digital Earth Example"
  }
  # DB Username
  db-username = "org${var.environment}"
}