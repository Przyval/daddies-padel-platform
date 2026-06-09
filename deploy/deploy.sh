#!/usr/bin/env bash
# Update deploy: pull latest code, install deps, migrate DB, restart service.
# Run on the VPS:  cd /opt/daddies/app && ./deploy/deploy.sh
set -euo pipefail

APP_DIR="/opt/daddies/app"
VENV="/opt/daddies/venv"

cd "$APP_DIR"
echo "==> Pulling latest code"
git pull --ff-only

echo "==> Installing dependencies"
"$VENV/bin/pip" install -q -r backend/requirements.txt

echo "==> Running database migrations"
cd backend
set -a; source /etc/daddies/env; set +a
"$VENV/bin/flask" db upgrade

echo "==> Restarting service"
sudo systemctl restart daddies
sleep 2
sudo systemctl --no-pager status daddies | head -5

echo "==> Health check"
curl -fsS https://api.daddiespadel.com/api/v1/health && echo "" && echo "✓ Deploy OK"
