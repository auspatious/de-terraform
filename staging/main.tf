locals {
  region = "us-west-2"
}

module "resources" {
  # This section is the customisation for the environment
  source           = "../resources"
  org-short-name   = "si"
  environment      = "staging"
  aws-region       = local.region
  subdomain        = "de-staging.spatialinsite.com.au"
  jhub_subdomain   = "de-jhub-staging.spatialinsite.com.au"

  # EKS stuff
  eks-version            = "1.33"
  coredns-version        = "v1.12.1-eksbuild.2"
  kube-proxy-version     = "v1.33.0-eksbuild.2"
  vpc-cni-version        = "v1.19.6-eksbuild.7"
  eks-karpenter-node-ami = "ubuntu-eks/k8s_1.33/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250625"

  # Database
  db-instance-class = "db.r8g.large"

  # SSO Admin Role ARN - Need to replace ACCOUNT_ID and TO_BE_UPDATED
  sso-admin-role-arn = "arn:aws:iam::971422685953:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_090ec2ad620e4a04"

  # Auth0 Tenant URL
  auth0-tenant = "https://dev-2o55e7xkn0n07wi6.auth0.com"
  
}

terraform {
  cloud {
    organization = "spatial-insite"
    workspaces {
      name = "org-staging"
    }
  }
}
