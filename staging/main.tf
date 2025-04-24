locals {
  region = "us-west-2"
}

module "resources" {
  # This section is the customisation for the environment
  source         = "../resources"
  environment    = "staging"
  aws-region     = local.region
  subdomain      = "staging.example.com"
  jhub_subdomain = "staging.example.com"

  # EKS stuff
  eks-version        = "1.31"
  coredns-version    = "v1.11.4-eksbuild.2"
  kube-proxy-version = "v1.29.11-eksbuild.2"
  vpc-cni-version    = "v1.19.2-eksbuild.1"

  # Database
  db-instance-class = "db.r8g.large"

  # SSO Admin Role ARN - Need to replace ACCOUNT_ID and TO_BE_UPDATED
  sso-admin-role-arn = "arn:aws:iam::ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_TO_BE_UPDATED"

  # Auth0 Tenant URL
  auth0-tenant = "https://example-org-staging.eu.auth0.com"
}

terraform {
  cloud {
    organization = "DigitalEarthExample"
    workspaces {
      name = "org-staging"
    }
  }
}
