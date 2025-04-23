resource "kubernetes_namespace" "odc" {
  metadata {
    name = "odc"
  }
}

# Only need the DB read secret in the ODC namespace. Writing is done in Argo.
resource "kubernetes_secret" "odcread_namespace_secret" {
  metadata {
    name      = "odcread-secret"
    namespace = kubernetes_namespace.odc.metadata[0].name
  }
  data = {
    username = "odcread"
    password = aws_secretsmanager_secret_version.odcread_password.secret_string
  }
  type = "Opaque"
}

# Generic read role for the OWS pods to read from the public bucket
module "service_account" {
  source = "../modules/service-account"

  name              = "data-reader"
  namespace         = "odc"
  oidc_provider_arn = module.eks.oidc_provider_arn
  write_bucket_names = [
    "fake-bucket"
  ]
  read_bucket_names = [
    "usgs-landsat",
    "copernicus-dem-30m",
    "e84-earth-search-sentinel-data",
    resource.aws_s3_bucket.public.id
  ]
  create_sa = true
}


# Set up a cloudfront cache for the `ows` endpoint
# Create a custom certificate
resource "aws_acm_certificate" "ows_cache" {
  provider          = aws.virginia
  domain_name       = "ows.${var.subdomain}"
  validation_method = "DNS"

  tags = merge(
    local.tags,
    {
      Name = "ows-cache"
    }
  )
}

# Validation of the certificate
resource "aws_route53_record" "ows_certificate" {
  for_each = {
    for dvo in aws_acm_certificate.ows_cache.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.subdomain.zone_id
}

resource "aws_acm_certificate_validation" "ows_certificate" {
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.ows_cache.arn
  validation_record_fqdns = [for record in aws_route53_record.ows_certificate : record.fqdn]
}

# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "ows_cache" {
  depends_on = [aws_acm_certificate_validation.ows_certificate]
  origin {
    domain_name = "ows-uncached.${var.subdomain}"
    origin_id   = "owsOrigin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }

    # Here is the custom header definition
    custom_header {
      name  = "X-Public-Host"
      value = "ows.${var.subdomain}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  aliases = [
    "ows.${var.subdomain}"
  ]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "owsOrigin"

    forwarded_values {
      query_string = true
      headers      = [
        "Origin",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
      ]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.ows_cache.arn
    ssl_support_method  = "sni-only"
  }

  # Don't cache 500, 502, 503 or 504 errors
  custom_error_response {
    error_caching_min_ttl = "0"
    error_code            = "500"
  }

  custom_error_response {
    error_caching_min_ttl = "0"
    error_code            = "502"
  }

  custom_error_response {
    error_caching_min_ttl = "0"
    error_code            = "503"
  }

  custom_error_response {
    error_caching_min_ttl = "0"
    error_code            = "504"
  }

  tags = merge(
    local.tags,
    {
      Name = "ows-cache"
    }
  )
}


# Set up DNS for the cloudfront distribution
resource "aws_route53_record" "ows_cache" {
  zone_id = data.aws_route53_zone.subdomain.zone_id
  name    = "ows"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.ows_cache.domain_name
    zone_id                = aws_cloudfront_distribution.ows_cache.hosted_zone_id
    evaluate_target_health = false
  }
}
