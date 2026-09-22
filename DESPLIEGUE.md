# Instrucciones de levantamiento — Prueba 1

Arquitectura: **Frontend SPA (Bootstrap)** + **API Gateway (API Manager)** + **Flask (API JSON)** en **EC2**, con **Cognito (IDaaS)** y login **OIDC Authorization Code + PKCE**.

```
Navegador (SPA) ──OIDC/PKCE──► Cognito Hosted UI ──► ID/Access token
      │
      └──HTTPS + Bearer JWT──► API Gateway (authorizer JWT: issuer + audience)
                                      │
                                      └──HTTP :8000──► EC2 (gunicorn + Flask) ──► SQLite
```

---

## 0. Requisitos

- Cuenta con acceso a **AWS Academy / laboratorio** (credenciales temporales).
- **Terraform** ≥ 1.5 y **AWS CLI** instalados localmente.
- Par de claves SSH: `ssh-keygen -t ed25519` (si no existe).
- Repositorio en **GitHub** con este código.
- `git`, `node` (opcional, para validar JS).

> Las credenciales del laboratorio expiran al cerrarlo. Solo se usan para `terraform apply`; los deploys diarios van por GitHub Actions con SSH.

---

## 1. Configurar credenciales de AWS

En el panel del laboratorio copia las credenciales y ejecuta:

```bash
aws configure
# AWS Access Key ID:     <del laboratorio>
# AWS Secret Access Key: <del laboratorio>
# Default region:        us-east-1
# Default output:        json
```

Si el laboratorio entrega token de sesión:

```bash
export AWS_SESSION_TOKEN="<del laboratorio>"
```

---

## 2. Configurar Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edita `terraform/terraform.tfvars`:

| Variable | Valor |
|---|---|
| `ssh_public_key` | Contenido de `~/.ssh/id_ed25519.pub` |
| `ssh_cidr` | `"0.0.0.0/0"` o restringe a tu IP `x.x.x.x/32` |
| `cognito_domain_prefix` | Prefijo **globalmente único**, ej. `cloud-native-juan-123` |
| `repo_url` | URL pública del repo GitHub (vacío si es privado) |
| `test_user_email` | Email de usuario de prueba, ej. `estudiante@duoc.cl` |

---

## 3. Levantar la infraestructura

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Crea: **EC2 t2.micro + EIP + Security Group (22, 8000)**, **CloudFront (HTTPS) → EC2:8000**, **Cognito user pool + app client (flujo `code`) + dominio Hosted UI + usuario de prueba**, **HTTP API con authorizer JWT y CORS (origen CloudFront)**.

Usuario de prueba (si definiste `test_user_email`): email indicado, contraseña `Admin1234`.

Guarda los outputs:

```bash
terraform -chdir=terraform output          # todos
terraform -chdir=terraform output -raw config_js
```

---

## 4. Configurar el frontend (`static/config.js`)

Pega el bloque del output `config_js` sobre el contenido de `static/config.js`:

```js
window.APP_CONFIG = {
  region: '...',
  userPoolId: '...',
  clientId: '...',
  hostedUiDomain: '...',
  apiGatewayUrl: '...',
  redirectUri: 'https://dXXXXXXXXXXXXX.cloudfront.net/',  // dominio CloudFront
  scopes: ['openid', 'email', 'profile'],
};
```

Los callback/logout URLs en Cognito ya los creó Terraform con el dominio CloudFront (HTTPS, requerido por Cognito); si cambias la distribución, vuelve a aplicar Terraform.

---

## 5. Secrets de GitHub

Repo GitHub → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Valor | Origen |
|---|---|---|
| `EC2_HOST` | IP pública de EC2 | `terraform output -raw ec2_public_ip` |
| `EC2_USER` | `ec2-user` | Usuario por defecto de Amazon Linux 2023 |
| `EC2_SSH_KEY` | Clave **privada** completa | `cat ~/.ssh/id_ed25519` (incluye `BEGIN/END`) |

**No** pongas access keys de AWS en GitHub: el workflow solo usa SSH.

---

## 6. Despliegue de código (GitHub Actions)

```bash
git add .
git commit -m "Prueba 1: API Gateway + Cognito + SPA PKCE"
git push origin main
```

El workflow `.github/workflows/deploy.yml`:

1. `rsync` del repo a EC2 (`~/cloud-native`).
2. Ejecuta `deploy.sh` (venv + gunicorn + systemd `cloud-native`).
3. Health check: `GET /api/computadores` y `/`.

Despliegue manual alternativo (sin Actions), por SSH a EC2:

```bash
scp -i ~/.ssh/id_ed25519 deploy.sh ec2-user@<IP>:~
ssh -i ~/.ssh/id_ed25519 ec2-user@<IP> 'APP_DIR=$HOME/cloud-native bash deploy.sh'
```

---

## 7. Evidencias para la prueba

### 7.1 API Manager sirve de intermediario

```bash
API=https://xxxxxxxx.execute-api.us-east-1.amazonaws.com
CF=https://dXXXXXXXXXXXXX.cloudfront.net

# Sin token → 401 (rechazado por el authorizer)
curl -i $API/api/computadores

# Sin token directo al backend (demuestra que la ruta protegida es la del API Manager)
curl -i $CF/api/computadores
```

### 7.2 JWT válido → 200; inválido → 401/403

1. Inicia sesión en la SPA y copia el token desde *DevTools → Network → oauth2/token* o decodifica el ID token (payload).
2. Con token:

```bash
TOKEN="<id_token>"

curl -i -H "Authorization: Bearer $TOKEN" $API/api/computadores          # 200 + JSON
curl -i -H "Authorization: Bearer $TOKEN" $API/api/computadores/999     # 404
curl -i -H "Authorization: Bearer $TOKEN" -X POST $API/api/computadores \
  -H "Content-Type: application/json" \
  -d '{"nombre":"PC-demo","cpu":"i5","ram":16,"marca":"Dell","tipo_almacenamiento":"SSD","capacidad_ssd":256}'   # 201

# Token basura / borrado → 401
curl -i -H "Authorization: Bearer xxx.yyy.zzz" $API/api/computadores
```

- **401**: sin token, token expirado o firma/issuer inválido.
- **403**: token válido pero audience/claims no autorizados (audience = clientId del app client; se configura en el authorizer de `terraform/apigateway.tf`).

Issuer y audience quedan fijados en Terraform:

```hcl
jwt_configuration {
  audience = [aws_cognito_user_pool_client.this.id]
  issuer   = "https://cognito-idp.<region>.amazonaws.com/<user_pool_id>"
}
```

### 7.3 OIDC Authorization Code + PKCE

En *DevTools → Network*, durante el login:

1. Petición a `/oauth2/authorize` con `response_type=code`, **`code_challenge`**, `code_challenge_method=S256`, **`state`** y **`nonce`**.
2. POST a `/oauth2/token` con `grant_type=authorization_code` y **`code_verifier`**.
3. Si `state` o `nonce` no coinciden, la SPA bloquea el token (prueba alterando `state` en la URL).

### 7.4 Cuenta en el tenant (registro)

En la SPA sin sesión: **Crear cuenta** → email + contraseña → código de verificación → **Confirmar** → iniciar sesión. En Cognito console → Users aparece el usuario con estado Confirmed.

### 7.5 Frontend y backend desplegados y activos

- Frontend: `https://dXXXXXXXXXXXXX.cloudfront.net/` responde 200 (Bootstrap + HTTPS).
- Backend: `ssh` a EC2 → `systemctl status cloud-native` (active/running).
- Integra: CRUD completo desde la SPA siempre pasa por el API Gateway (ver pestaña Network: llamadas a `execute-api...`).

### 7.6 CORS en el API Manager

Desde el navegador (SPA en CloudFront), las llamadas a `execute-api` responden con cabeceras `access-control-allow-origin` del origen permitido (dominio CloudFront). En Terraform está en `aws_apigatewayv2_api.this.cors_configuration` (origen exacto CloudFront, sin `*`).

---

## 8. Comandos útiles

```bash
# Estado del servicio en EC2
ssh -i ~/.ssh/id_ed25519 ec2-user@<IP>
sudo systemctl status cloud-native
sudo journalctl -u cloud-native -f

# Terraform
terraform -chdir=terraform output -raw api_gateway_url
terraform -chdir=terraform output -raw cloudfront_domain
terraform -chdir=terraform destroy    # al cerrar el laboratorio (evita cargos)

# Re-desplegar código tras cambios
git push origin main
```

---

## 9. Troubleshooting

| Síntoma | Causa probable |
|---|---|
| Workflow falla en SSH | Secret `EC2_SSH_KEY` mal pegado o `EC2_HOST` incorrecto |
| 401 con token bueno | `audience`/`issuer` del authorizer ≠ app client / user pool |
| Error `redirect_uri` en login | IP elástica cambió → reaplicar Terraform o corregir callback en Cognito |
| Cognito `InvalidOAuthParameter` | Revisa `hostedUiDomain`, `clientId` y scopes en `config.js` |
| `venv` falla en EC2 | `deploy.sh` reintenta instalando paquetes (requiere sudo sin password, default en AMI) |
| Credenciales Terraform expiradas | Cierra/reabre el laboratorio y vuelve a `aws configure` |
