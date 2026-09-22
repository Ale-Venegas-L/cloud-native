#!/usr/bin/env bash
# Despliegue idempotente en EC2. Útil en primera ejecución manual y desde GitHub Actions.
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/cloud-native}"
REPO_URL="${REPO_URL:-}"
PORT="${PORT:-8000}"
SKIP_OS_UPDATE="${SKIP_OS_UPDATE:-0}"

if ! python3 -m venv --help >/dev/null 2>&1 || ! python3 -c "import venv" 2>/dev/null; then
  SKIP_OS_UPDATE=0
fi
python3 -m venv /tmp/.venv-check-$$ 2>/dev/null || SKIP_OS_UPDATE=0
rm -rf /tmp/.venv-check-$$

if [ "$SKIP_OS_UPDATE" != "1" ]; then
  echo "== Actualizando sistema =="
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf -y update
    sudo dnf -y install python3 python3-pip git
  else
    sudo apt-get update
    sudo apt-get -y install python3 python3-pip python3-venv git
  fi
fi

if [ ! -f "$APP_DIR/app.py" ]; then
  if [ -n "$REPO_URL" ]; then
    echo "== Clonando $REPO_URL =="
    git clone "$REPO_URL" "$APP_DIR"
  else
    echo "ERROR: no existe $APP_DIR y no se definió REPO_URL" >&2
    exit 1
  fi
fi

echo "== Virtualenv + dependencias =="
if [ ! -x "$APP_DIR/.venv/bin/python" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi
"$APP_DIR/.venv/bin/pip" install --upgrade pip -q
"$APP_DIR/.venv/bin/pip" install -q -r "$APP_DIR/requirements.txt"

echo "== Servicio systemd (gunicorn en el puerto $PORT) =="
sudo tee /etc/systemd/system/cloud-native.service > /dev/null <<EOF
[Unit]
Description=Cloud Native Flask API + SPA
After=network.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/.venv/bin/gunicorn --bind 0.0.0.0:$PORT --workers 2 app:app
Restart=always
User=${USER}
Environment=PORT=$PORT

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cloud-native
sudo systemctl restart cloud-native
sleep 2

echo "== Health check =="
curl -sf "http://localhost:$PORT/api/computadores"
echo
echo "== Despliegue OK =="
