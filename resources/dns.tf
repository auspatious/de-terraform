# This is the subdomain we're using, for now.
data "aws_route53_zone" "subdomain" {
    name = var.subdomain
}
