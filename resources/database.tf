# A postgres database in the private subnet
resource "random_password" "db_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_random_string.result
}

resource "aws_db_subnet_group" "default" {
  name       = "db"
  subnet_ids = module.vpc.private_subnets
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "db-sg"
  description = "PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.2.3"

  identifier                     = "${local.cluster_name}-app-db"
  instance_use_identifier_prefix = true

  create_db_option_group    = false
  create_db_parameter_group = false

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db-instance-class

  allocated_storage = 100

  create_random_password = false
  db_name                = "org"
  username               = local.db-username
  password               = aws_secretsmanager_secret_version.db_password.secret_string
  port                   = 5432

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 10

  # Prevent accidental deletion and re-building
  deletion_protection = true

  tags = local.tags
}

resource "kubernetes_namespace" "db" {
  metadata {
    name = "db"
  }
}

resource "kubernetes_service" "db_endpoint" {
  metadata {
    name      = "db-endpoint"
    namespace = resource.kubernetes_namespace.db.metadata[0].name
  }
  spec {
    type          = "ExternalName"
    external_name = split(":", module.db.db_instance_endpoint)[0]
    port {
      port        = 5432
      target_port = 5432
    }
  }
  wait_for_load_balancer = false
}

resource "kubernetes_secret" "db_admin_argo" {
  metadata {
    name      = "db-admin"
    namespace = resource.kubernetes_namespace.argo.metadata[0].name
  }

  data = {
    # TODO: deprecate these long ones!
    postgres-username = local.db-username
    postgres-password = aws_secretsmanager_secret_version.db_password.secret_string
    username          = local.db-username
    password          = aws_secretsmanager_secret_version.db_password.secret_string
  }

  type = "Opaque"
}

# A big set of secrets
# Argo
resource "random_password" "argo_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "argo_password" {
  name = "argo-password"
}

resource "aws_secretsmanager_secret_version" "argo_password" {
  secret_id     = aws_secretsmanager_secret.argo_password.id
  secret_string = random_password.argo_random_string.result
}


# Grafana 
resource "random_password" "grafana_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "grafana_password" {
  name = "grafana-password"
}

resource "aws_secretsmanager_secret_version" "grafana_password" {
  secret_id     = aws_secretsmanager_secret.grafana_password.id
  secret_string = random_password.grafana_random_string.result
}


# Jupyterhub
resource "random_password" "jupyterhub_random_string" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "jupyterhub_password" {
  name = "jupyterhub-password"
}

resource "aws_secretsmanager_secret_version" "jupyterhub_password" {
  secret_id     = aws_secretsmanager_secret.jupyterhub_password.id
  secret_string = random_password.jupyterhub_random_string.result
}

# STAC Writer
resource "random_password" "stac_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "stac_password" {
  name = "stac-password"
}

resource "aws_secretsmanager_secret_version" "stac_password" {
  secret_id     = aws_secretsmanager_secret.stac_password.id
  secret_string = random_password.stac_random_string.result
}


# STAC Reader
resource "random_password" "stacread_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "stacread_password" {
  name = "stacread-password"
}

resource "aws_secretsmanager_secret_version" "stacread_password" {
  secret_id     = aws_secretsmanager_secret.stacread_password.id
  secret_string = random_password.stacread_random_string.result
}

# ODC Writer
resource "random_password" "odc_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "odc_password" {
  name = "odc-password"
}

resource "aws_secretsmanager_secret_version" "odc_password" {
  secret_id     = aws_secretsmanager_secret.odc_password.id
  secret_string = random_password.odc_random_string.result
}


# ODC Reader
resource "random_password" "odcread_random_string" {
  length           = 32
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "odcread_password" {
  name = "odcread-password"
}

resource "aws_secretsmanager_secret_version" "odcread_password" {
  secret_id     = aws_secretsmanager_secret.odcread_password.id
  secret_string = random_password.odcread_random_string.result
}
