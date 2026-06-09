#!/usr/bin/env bash
# Update deploy: pull latest code, install deps, migrate DB, restart service.
# Run on the VPS:  cd /opt/daddies/app && ./deploy/deploy.sh
#
# Fails hard: if migration fails, the running service is NOT restarted (old
# version keeps serving). If the post-restart healthcheck fails, exits non-zero.
set -Eeuo pipefail

# Resolve the repo root from THIS script's location, not the current working
# directory — works no matter where deploy.sh is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# venv lives outside the repo; override with VENV=... if you installed elsewhere.
VENV="${VENV:-/opt/daddies/venv}"
HEALTH_URL="${HEALTH_URL:-https://api.daddiespadel.com/api/v1/health}"

trap 'echo "✗ Deploy FAILED at line $LINENO. Service was not changed past this point."; exit 1' ERR

cd "$APP_DIR"

echo "==> Pulling latest code"
git pull --ff-only

echo "==> Installing dependencies"
"$VENV/bin/pip" install -q -r backend/requirements.txt

echo "==> Running database migrations (before restart — abort here on failure)"
cd backend
set -a; source /etc/daddies/env; set +a
"$VENV/bin/flask" db upgrade

echo "==> Restarting service"
sudo systemctl restart daddies
sleep 2

echo "==> Healthcheck"
if ! curl -fsS "$HEALTH_URL" >/dev/null; then
    echo "✗ Healthcheck failed after restart. Recent logs:"
    sudo journalctl -u daddies -n 40 --no-pager
    exit 1
fi

echo "✓ Deploy OK — $(curl -fsS "$HEALTH_URL")"
