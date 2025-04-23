resource "kubernetes_namespace" "stac" {
  metadata {
    name = "stac"
  }
}

# NOTE: the username and password are created in the db file

# Only need the read secret in the STAC namespace. Writing is done in Argo.
resource "kubernetes_secret" "stacread_namespace_secret" {
  metadata {
    name      = "stacread-secret"
    namespace = kubernetes_namespace.stac.metadata[0].name
  }
  data = {
    username = "stacread"
    password = aws_secretsmanager_secret_version.stacread_password.secret_string
  }
  type = "Opaque"
}
