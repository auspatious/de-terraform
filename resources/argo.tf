resource "kubernetes_namespace" "argo" {
  metadata {
    name = "argo"
  }
}

data "aws_secretsmanager_secret_version" "argo_client_secret" {
  secret_id = "argo-client-and-secret"
}

resource "kubernetes_secret" "argo_server_sso" {
  metadata {
    name      = "argo-client-secret"
    namespace = kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    client-id     = split(":", data.aws_secretsmanager_secret_version.argo_client_secret.secret_string)[0]
    client-secret = split(":", data.aws_secretsmanager_secret_version.argo_client_secret.secret_string)[1]
  }

  type = "Opaque"
}

# Create a bucket, user and access keys for Argo's artifact storage
resource "aws_s3_bucket" "argo" {
  bucket = "org-argo-artifacts-dep-${var.environment}"
  tags   = local.tags
}

# Argo system service account, with read/write access to the storage bucket
module "argo_artifact_service_account" {
  source = "../modules/service-account"

  name              = "argo-artifact-read-write-sa"
  namespace         = "argo"
  oidc_provider_arn = module.eks.oidc_provider_arn
  write_bucket_names = [
    resource.aws_s3_bucket.argo.bucket
  ]
  read_bucket_names = [
    resource.aws_s3_bucket.argo.bucket
  ]
  create_sa = true
}

# Create a policy to read/write the bucket
resource "aws_iam_policy" "argo_artifact_read_write_policy" {
  name        = "argo-artifact-read-write"
  description = "Policy to read/write Argo artifacts"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ],
        Resource = [
          aws_s3_bucket.argo.arn,
          "${aws_s3_bucket.argo.arn}/*",
        ],
      },
    ],
  })
}

# And a role
resource "aws_iam_role" "argo_artifact_read_write_role" {
  name = "argo-artifact-read-write"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}



# And a user
resource "aws_iam_user" "argo_artifact_read_write_user" {
  name = "argo-artifact-read-write"
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "argo_artifact_read_write_policy_attachment" {
  role       = aws_iam_role.argo_artifact_read_write_role.name
  policy_arn = aws_iam_policy.argo_artifact_read_write_policy.arn
}

# Attach the policy to the user
resource "aws_iam_user_policy_attachment" "argo_artifact_read_write_user_policy_attachment" {
  user       = aws_iam_user.argo_artifact_read_write_user.name
  policy_arn = aws_iam_policy.argo_artifact_read_write_policy.arn
}

# Create access keys for the user
resource "aws_iam_access_key" "argo_artifact_read_write_access_key" {
  user = aws_iam_user.argo_artifact_read_write_user.name
}

# Create a secret for the access keys
resource "kubernetes_secret" "argo_artifact_read_write" {
  metadata {
    name      = "argo-artifact-read-write"
    namespace = kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    access-key = aws_iam_access_key.argo_artifact_read_write_access_key.id
    secret-key = aws_iam_access_key.argo_artifact_read_write_access_key.secret
  }
}


### SECRETS
resource "kubernetes_secret" "jupyterhub_secret" {
  metadata {
    name      = "jupyterhub"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "jupyterhub"
    password = aws_secretsmanager_secret_version.jupyterhub_password.secret_string
  }
  type = "Opaque"
}

resource "kubernetes_secret" "argo_secret" {
  metadata {
    name      = "argo"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "argo"
    password = aws_secretsmanager_secret_version.argo_password.secret_string
  }
  type = "Opaque"
}

resource "kubernetes_secret" "grafana_secret" {
  metadata {
    name      = "grafana"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "grafana"
    password = aws_secretsmanager_secret_version.grafana_password.secret_string
  }
  type = "Opaque"
}

resource "kubernetes_secret" "stacread_secret" {
  metadata {
    name      = "stacread"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "stacread"
    password = aws_secretsmanager_secret_version.stacread_password.secret_string
  }
  type = "Opaque"
}


resource "kubernetes_secret" "stac_secret" {
  metadata {
    name      = "stac"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "stac"
    password = aws_secretsmanager_secret_version.stac_password.secret_string
  }
  type = "Opaque"
}


resource "kubernetes_secret" "odcread_secret" {
  metadata {
    name      = "odcread"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "odcread"
    password = aws_secretsmanager_secret_version.odcread_password.secret_string
  }
  type = "Opaque"
}


resource "kubernetes_secret" "odc_secret" {
  metadata {
    name      = "odc"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }
  data = {
    username = "odc"
    password = aws_secretsmanager_secret_version.odc_password.secret_string
  }
  type = "Opaque"
}
