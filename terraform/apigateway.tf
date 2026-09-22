# API Manager: HTTP API con authorizer JWT (issuer + audience de Cognito) y CORS

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    # ⚠️ Origen del frontend (debe coincidir con frontend_base_url sin barra final)
    allow_origins  = [var.frontend_base_url]
    allow_headers  = ["content-type", "authorization"]
    allow_methods  = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    expose_headers = ["*"]
    max_age        = 3600
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.this.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  }
}

resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${aws_eip.this.public_ip}:8000"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "list" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /api/computadores"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_route" "get_one" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /api/computadores/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_route" "create" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /api/computadores"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_route" "update" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "PUT /api/computadores/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_route" "delete" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "DELETE /api/computadores/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 10
  }
}
