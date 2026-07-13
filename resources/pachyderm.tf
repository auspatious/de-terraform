# Create a bucket for pachyderm's artifact storage
resource "aws_s3_bucket" "pachyderm" {
  bucket = "${var.org-short-name}-pachyderm-artifacts-${var.environment}"
  tags   = local.tags
}

# Create namespace
resource "kubernetes_namespace" "pachyderm" {
  metadata {
    name = "pachyderm"
  }
}

# Pachyderm system service account, with read/write access to the storage bucket
module "pachyderm_artifact_service_account" {
  source = "../modules/service-account"

  name              = "pachyderm"
  namespace         = "pachyderm"
  oidc_provider_arn = module.eks.oidc_provider_arn
  write_bucket_names = [
    resource.aws_s3_bucket.pachyderm.bucket
  ]
  read_bucket_names = [
    resource.aws_s3_bucket.pachyderm.bucket
  ]
  create_sa = false
}

resource "kubernetes_secret" "pachyderm" {
  metadata {
    name      = "pachyderm-values"
    namespace = kubernetes_namespace.pachyderm.metadata[0].name
  }

  data = {
    "values.yaml" = templatefile("${path.module}/config/pachyderm.yaml", {
      username      = "pachyderm"
      password      = aws_secretsmanager_secret_version.pachyderm_password.secret_string
      database-name = "pachyderm"
      database-host = "db-endpoint.db.svc.cluster.local"
      bucket-name   = resource.aws_s3_bucket.pachyderm.bucket
      svc-account   = module.pachyderm_artifact_service_account.iam_role_arn
    })
  }

  type = "Opaque"
}

