output "ec2_public_ip" {
  description = "IP pública de EC2 (para Security Group, pruebas y secretos de GitHub)"
  value       = aws_eip.this.public_ip
}

output "ec2_public_dns" {
  description = "DNS público de EC2"
  value       = aws_instance.this.public_dns
}

output "cognito_domain_full" {
  description = "Dominio Hosted UI completo (prefijo + sufijo aleatorio)"
  value       = "${var.project_name}-${random_id.suffix.hex}"
}

output "api_gateway_url" {
  description = "URL del API Manager (va en static/config.js apiGatewayUrl)"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "user_pool_id" {
  description = "Tenant IDaaS (va en static/config.js userPoolId)"
  value       = aws_cognito_user_pool.this.id
}

output "app_client_id" {
  description = "clientId de la aplicación SPA (va en static/config.js clientId)"
  value       = aws_cognito_user_pool_client.this.id
}

output "cognito_domain" {
  description = "Prefijo del dominio Hosted UI (va en static/config.js hostedUiDomain)"
  value       = "${var.project_name}-${random_id.suffix.hex}"
}

output "config_js" {
  description = "Bloque listo para pegar en static/config.js (actualiza redirectUri con tu URL HTTPS final)"
  value       = <<-EOT
    region: '${var.region}',
    userPoolId: '${aws_cognito_user_pool.this.id}',
    clientId: '${aws_cognito_user_pool_client.this.id}',
    hostedUiDomain: '${var.project_name}-${random_id.suffix.hex}',
    apiGatewayUrl: '${aws_apigatewayv2_api.this.api_endpoint}',
    redirectUri: '${var.frontend_base_url}/',
  EOT
}

output "github_secrets" {
  description = "Valores para los secrets del workflow deploy.yml"
  value = {
    EC2_HOST    = aws_eip.this.public_ip
    EC2_USER    = "ec2-user"
    EC2_SSH_KEY = "<contenido de tu clave privada ~/.ssh/id_ed25519>"
  }
}
