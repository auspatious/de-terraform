resource "aws_cognito_user_pool" "pool" {
  name = "${var.org-short-name}-de-cognito-user-pool"

}

resource "aws_cognito_user_pool_domain" "pool" {
  domain       = var.org-short-name
  user_pool_id = aws_cognito_user_pool.pool.id
}