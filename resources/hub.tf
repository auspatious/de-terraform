data "aws_secretsmanager_secret_version" "hub_client_secret" {
  secret_id = "hub-client-secret"
}

resource "kubernetes_namespace" "hub" {
  metadata {
    name = "hub"
  }
}

resource "random_id" "jhub_hub_cookie_secret_token" {
  byte_length = 32
}

resource "random_id" "jhub_proxy_secret_token" {
  byte_length = 32
}

resource "random_password" "dask_gateway_api_token" {
  length  = 64
  special = false
  upper   = false
}

resource "kubernetes_secret" "jupyterhub" {
  metadata {
    name      = "jupyterhub"
    namespace = kubernetes_namespace.hub.metadata[0].name
  }

  data = {
    "values.yaml" = templatefile("${path.module}/config/jupyterhub.yaml", {
      region    = var.aws-region
      host_name = var.jhub_subdomain

      # auth
      jhub_auth_client_id     = split(":", data.aws_secretsmanager_secret_version.hub_client_secret.secret_string)[0]
      jhub_auth_client_secret = split(":", data.aws_secretsmanager_secret_version.hub_client_secret.secret_string)[1]

      # Need to strip the https:// off the front and .auth0.com off the back
      auth0_tenant = trimsuffix(trimprefix(var.auth0-tenant, "https://"), ".auth0.com")

      # Jupyterhub hub database
      jhub_db_name     = "jupyterhub"
      jhub_db_username = "jupyterhub"
      jhub_db_password = aws_secretsmanager_secret_version.jupyterhub_password.secret_string
      jhub_db_hostname = "db-endpoint.db.svc.cluster.local"

      # Secrets
      jhub_hub_cookie_secret_token = random_id.jhub_hub_cookie_secret_token.hex
      jhub_proxy_secret_token      = random_id.jhub_proxy_secret_token.hex
      jhub_dask_gateway_api_token  = random_password.dask_gateway_api_token.result
    })
  }

  type = "Opaque"
}

resource "kubernetes_secret" "hub-dask-token" {
  metadata {
    name      = "hub-dask-token"
    namespace = kubernetes_namespace.hub.metadata[0].name
  }

  data = {
    token = random_password.dask_gateway_api_token.result
  }

  type = "Opaque"
}

# Generic S3 read policy for users
resource "aws_iam_policy" "hub_user_read_policy" {
  name        = "hub_user_read_policy"
  description = "Hub user read policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "S3:GetBucketLocation",
          "S3:GetObject",
          "S3:GetObjectAcl",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::usgs-landsat",
          "arn:aws:s3:::usgs-landsat/*",
        ]
      },
    ]
  })
}

# role
module "iam_eks_role_hub_reader" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "svc-hub-user-read"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["hub:user-read"]
    }
  }

  role_policy_arns = {
    HubUserRead = aws_iam_policy.hub_user_read_policy.arn
  }
}

# services account
resource "kubernetes_service_account" "hub_user_read" {
  metadata {
    name      = "user-read"
    namespace = "hub"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_hub_reader.iam_role_arn
    }
  }
  automount_service_account_token = true
}

# Grab DB Secret into this namespace
resource "kubernetes_secret" "hub_db_secret" {
  metadata {
    name      = "hub-db-secret"
    namespace = kubernetes_namespace.hub.metadata[0].name
  }
  data = {
    username = "jupyterhub"
    password = aws_secretsmanager_secret_version.jupyterhub_password.secret_string
  }
  type = "Opaque"
}

