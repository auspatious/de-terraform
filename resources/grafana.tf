resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

data "aws_secretsmanager_secret_version" "grafana_client_secret" {
  secret_id = "grafana-client-and-secret"
}

# Generate a random password for Grafana admin user
resource "random_bytes" "grafana_admin_password" {
  length = 32
}


resource "kubernetes_secret" "grafana_admin_credentials" {

  metadata {
    name      = "grafana-admin-secret"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    admin-user     = "grafanasuperuser"
    admin-password = random_bytes.grafana_admin_password.hex
  }

  type = "Opaque"
}

resource "kubernetes_secret" "grafana" {
  metadata {
    name      = "grafana-values"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "values.yaml" = templatefile("${path.module}/config/grafana.yaml", {
      # Database
      # db_host     = "db-endpoint.db.svc.cluster.local"
      # db_user     = split(":", data.azurerm_key_vault_secret.grafana_db_creds.value)[0]
      # db_password = split(":", data.azurerm_key_vault_secret.grafana_db_creds.value)[1]

      # Authorisation
      auth0-tenant  = var.auth0-tenant
      client-id     = split(":", data.aws_secretsmanager_secret_version.grafana_client_secret.secret_string)[0]
      client-secret = split(":", data.aws_secretsmanager_secret_version.grafana_client_secret.secret_string)[1]
    })
  }

  type = "Opaque"
}
