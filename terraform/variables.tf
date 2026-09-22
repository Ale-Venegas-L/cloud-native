variable "region" {
  description = "Región de AWS (AWS Academy suele usar us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre base de los recursos"
  type        = string
  default     = "cloud-native"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (free tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "Clave pública SSH para conectarte a EC2 (~/.ssh/id_ed25519.pub o id_rsa.pub)"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR permitido para SSH (restringe a tu IP si es posible)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cognito_domain_prefix" {
  description = "Prefijo base del dominio Hosted UI (se le añade sufijo aleatorio para unicidad)"
  type        = string
  default     = "cloud-native"
}

variable "repo_url" {
  description = "URL del repositorio Git (opcional; se clona en el arranque de EC2)"
  type        = string
  default     = ""
}

variable "test_user_email" {
  description = "Email de usuario de prueba creado en el user pool (vacío = no crear)"
  type        = string
  default     = ""
}

# ⚠️ DEBE SER HTTPS para que Cognito acepte callbacks.
# Usa el DNS público de la EC2 (certificado autofirmado, puerto 443).
# Valor ejemplo: "https://ec2-xx-xx-xx-xx.compute-1.amazonaws.com"
variable "frontend_base_url" {
  description = "URL base del frontend (HTTPS). Se usa en callbacks Cognito y CORS API GW."
  type        = string
}
