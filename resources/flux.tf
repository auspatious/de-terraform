# Create a secret in the flux-system namespace with the slack webhook
# From the secretmanager secret called flux-webhook
data "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id = "flux-webhook"
}

resource "kubernetes_secret" "slack_webhook" {
  metadata {
    name      = "slack-webhook"
    namespace = "flux-system"
  }
  data = {
    "address" = data.aws_secretsmanager_secret_version.slack_webhook.secret_string
  }
}
