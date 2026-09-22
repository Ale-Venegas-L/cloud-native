# IDaaS: tenant (user pool) + aplicación (app client) + dominio Hosted UI

resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  schema {
    name                = "email"
    required            = true
    attribute_data_type = "String"
    mutable             = false
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.project_name}-${random_id.suffix.hex}"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.project_name}-spa"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # ⚠️ DEBE SER HTTPS. Terraform usa la variable frontend_base_url (por defecto HTTP a la IP).
  # Tras aplicar, crea tu distribución CloudFront / ALB / nginx+TLS y actualiza
  # esta variable en terraform.tfvars y vuelve a aplicar, o edita el app client en consola.
  callback_urls = ["${var.frontend_base_url}/"]
  logout_urls   = ["${var.frontend_base_url}/"]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
}

# Usuario de prueba del tenant (queda CONFIRMED sin depender del email)
resource "aws_cognito_user" "test" {
  count = var.test_user_email != "" ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this.id
  username     = var.test_user_email

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  message_action = "SUPPRESS"

  password = "Admin1234"

  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.this.id} \
        --username "${var.test_user_email}" \
        --password "Admin1234" \
        --permanent \
        --region ${var.region}
    EOT
  }

  lifecycle {
    ignore_changes = [password]
  }
}
