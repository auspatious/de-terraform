# Public data bucket
resource "aws_s3_bucket" "public" {
  bucket = "org-public-${var.environment}"

  # Keep the bucket and contents safe!
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

resource "aws_s3_bucket_ownership_controls" "public_ownership" {
  bucket = aws_s3_bucket.public.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.public.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "public" {
  depends_on = [
    aws_s3_bucket_ownership_controls.public_ownership,
    aws_s3_bucket_public_access_block.public_access
  ]

  bucket = aws_s3_bucket.public.id
  acl    = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.public.id
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.public.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ],
        Resource = [
          "${aws_s3_bucket.public.arn}",
          "${aws_s3_bucket.public.arn}/*",
        ],
      },
    ],
  })
}

resource "aws_s3_bucket_website_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

output "public_bucket_arn" {
  value = aws_s3_bucket.public.arn
}

output "public_bucket_name" {
  value = aws_s3_bucket.public.bucket
}
