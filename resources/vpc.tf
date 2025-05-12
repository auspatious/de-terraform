module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.org-short-name}-vpc-${var.environment}"

  azs             = ["${var.aws-region}a", "${var.aws-region}b", "${var.aws-region}c"]

  enable_ipv6 = false
  cidr = "10.0.0.0/16"
  private_subnets = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  public_subnets  = ["10.0.112.0/20", "10.0.128.0/20", "10.0.144.0/20"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_vpn_gateway     = false

  enable_dns_hostnames = true

  # From Karpenter example https://github.com/clowdhaus/eks-reference-architecture/blob/main/karpenter/vpc.tf
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.org-short-name}-${var.environment}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.org-short-name}-${var.environment}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.org-short-name}-${var.environment}-default" }

  public_subnet_tags = {
    "SubnetType"             = "Public"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "SubnetType"                      = "Private"
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = data.aws_vpc_endpoint_service.s3.service_name

  route_table_ids = flatten([module.vpc.private_route_table_ids])
  tags = merge(local.tags, {
    "Name" = "s3-vpc-endpoint"
    }
  )
}

output "vpc_id" {
  description = "The VPC ID for the Staging VPC"
  value       = module.vpc.vpc_id
}
