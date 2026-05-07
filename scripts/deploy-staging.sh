#!/bin/bash
# =============================================================================
# Daddies Padel Platform — Staging Deploy Script
# =============================================================================
# Usage: ./deploy-staging.sh
#
# This script:
#   1. Builds the Flutter web app (release mode)
#   2. Serves it on port 8080
#   3. Exposes it via Cloudflare Tunnel (free public URL)
#
# Anyone with the URL can access the latest version.
# To push an update: kill this script, run it again.
# =============================================================================

set -e

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     DADDIES PADEL — STAGING DEPLOY       ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# Step 1: Build
echo "→ Building Flutter web (release)..."
flutter build web --no-wasm-dry-run 2>&1 | tail -3
echo "  ✓ Build complete"
echo ""

# Step 2: Kill any existing server on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
sleep 1

# Step 3: Serve the build
echo "→ Starting local server on port 8080..."
cd build/web
python3 -m http.server 8080 --bind 0.0.0.0 > /dev/null 2>&1 &
SERVER_PID=$!
cd ../..
sleep 1
echo "  ✓ Local server running (PID: $SERVER_PID)"
echo ""

# Step 4: Tunnel
echo "→ Opening Cloudflare Tunnel..."
echo "  (Public URL will appear below)"
echo ""
echo "═══════════════════════════════════════════════"
cloudflared tunnel --url http://localhost:8080 2>&1 | grep -E "https://.*trycloudflare\.com|INF"

# Cleanup on exit
trap "kill $SERVER_PID 2>/dev/null; echo '  Staging server stopped.'" EXIT
