# Bucket Policy, includes separate read and write policies
resource "aws_iam_policy" "read_write_policy" {
  name        = "svc-${var.name}-bucket-policy"
  description = "Bucket reader policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read
        Action = [
          "s3:ListBucket",
          "S3:GetObject",
          "S3:GetObjectAcl",
        ]
        Effect = "Allow"

        Resource = flatten(
          concat([
            for bucket in var.read_bucket_names : [
              "arn:aws:s3:::${bucket}",
              "arn:aws:s3:::${bucket}/*"
            ]
            ],
            [
              for bucket in var.write_bucket_names : [
                "arn:aws:s3:::${bucket}",
                "arn:aws:s3:::${bucket}/*"
              ]
            ]
          )
        )
      },
      {
        # Write
        Action = [
          "S3:PutObject",
          "S3:PutObjectAcl"
        ]
        Effect = "Allow"

        Resource = flatten([
          for bucket in var.write_bucket_names : [
            "arn:aws:s3:::${bucket}",
            "arn:aws:s3:::${bucket}/${var.write_path}*"
          ]
        ])
      }
    ]
  })
}

# Bucket role
module "iam_eks_role_bucket" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "svc-${var.name}"
  max_session_duration = var.max_session_duration

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.name}"]
    }
  }

  role_policy_arns = {
    ReadWritePolicy = aws_iam_policy.read_write_policy.arn
  }
}

# k8s service account for bucket writing, only create if the variable "create_sa" is set to true
resource "kubernetes_service_account" "bucket" {
  count = var.create_sa ? 1 : 0
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_bucket.iam_role_arn
    }
  }
  automount_service_account_token = true
}

# Bind to an argo workflows role if it's in the argo namespace
resource "kubernetes_role_binding" "bucket" {
  count = var.namespace == "argo" && var.create_sa ? 1 : 0
  metadata {
    name      = "${var.name}-role-binding"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "argo-workflows-workflow"
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
  }
}