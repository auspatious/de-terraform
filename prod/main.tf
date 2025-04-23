locals {
  region = "us-west-2"
}

module "resources" {
  # This section is the customisation for the environment
  source         = "../resources"
  environment    = "prod"
  aws-region     = local.region
  subdomain      = "prod.digitalearthpacific.io"
  jhub_subdomain = "digitalearthpacific.org"

  # EKS stuff
  eks-version        = "1.31"
  coredns-version    = "v1.11.4-eksbuild.2"
  kube-proxy-version = "v1.29.11-eksbuild.2"
  vpc-cni-version    = "v1.19.2-eksbuild.1"

  # Database
  db-instance-class = "db.m5.4xlarge"

  # SSO Admin Role ARN
  sso-admin-role-arn = "arn:aws:iam::533267299239:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_520c3bb14e78482b"

  # Auth0 Tenant URL
  auth0-tenant = "https://digitalearthpacific.au.auth0.com"
}

terraform {
  cloud {
    organization = "DigitalEarthPacific"
    workspaces {
      name = "dep-prod"
    }
  }
}

output "cluster_oidc_issuer_url" {
  value = module.resources.cluster_oidc_issuer_url
}

output "cluster_tls_certificate_sha1_fingerprint" {
  value = module.resources.cluster_tls_certificate_sha1_fingerprint
}
