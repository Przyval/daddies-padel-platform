#!/usr/bin/env bash
# Post-deploy API smoke test. Run from anywhere against the live VPS:
#   ./deploy/smoke_test.sh https://api.daddiespadel.com
# Exits non-zero if any gate fails. Does NOT print tokens.
set -uo pipefail

BASE="${1:-https://api.daddiespadel.com}"
API="$BASE/api/v1"
PASS=0; FAIL=0
ts=$(date +%s)
EMAIL="smoke+$ts@test.local"

check() { # desc, expected_code, actual_code
  if [ "$2" = "$3" ]; then echo "  ✓ $1 ($3)"; PASS=$((PASS+1));
  else echo "  ✗ $1 — expected $2, got $3"; FAIL=$((FAIL+1)); fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "== Smoke test: $API =="

echo "[1] health"
check "GET /health 200" 200 "$(code "$API/health")"

echo "[2] auth"
REG=$(curl -s -X POST "$API/auth/register" -H 'Content-Type: application/json' \
  -d "{\"username\":\"Smoke $ts\",\"email\":\"$EMAIL\",\"phone\":\"08$ts\",\"password\":\"rahasia123\"}")
echo "$REG" | grep -q '"ok": *true\|"ok":true' && { echo "  ✓ register ok"; PASS=$((PASS+1)); } || { echo "  ✗ register failed: $REG"; FAIL=$((FAIL+1)); }

LOGIN=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"rahasia123\"}")
ACCESS=$(printf '%s' "$LOGIN" | sed -n 's/.*"access_token": *"\([^"]*\)".*/\1/p')
REFRESH=$(printf '%s' "$LOGIN" | sed -n 's/.*"refresh_token": *"\([^"]*\)".*/\1/p')
[ -n "$ACCESS" ] && { echo "  ✓ login returns token"; PASS=$((PASS+1)); } || { echo "  ✗ login no token"; FAIL=$((FAIL+1)); }

echo "[3] protected endpoints"
check "GET /me no token → 401"      401 "$(code "$API/me")"
check "GET /me bad token → 401/422" 422 "$(code "$API/me" -H 'Authorization: Bearer not.a.real.token')"
check "GET /me with token → 200"    200 "$(code "$API/me" -H "Authorization: Bearer $ACCESS")"
check "GET /membership → 200"       200 "$(code "$API/membership" -H "Authorization: Bearer $ACCESS")"
check "POST /auth/refresh → 200"    200 "$(code -X POST "$API/auth/refresh" -H "Authorization: Bearer $REFRESH")"

echo "[4] validation"
check "register short password → 422" 422 "$(code -X POST "$API/auth/register" -H 'Content-Type: application/json' -d '{"username":"x","email":"x@x.com","phone":"0","password":"123"}')"
check "login wrong password → 401"    401 "$(code -X POST "$API/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"salah\"}")"

echo "[5] rate limit (login is 10/min → expect a 429 within ~15 tries)"
got429=no
for i in $(seq 1 15); do
  c=$(code -X POST "$API/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"salah\"}")
  [ "$c" = "429" ] && { got429=yes; break; }
done
[ "$got429" = "yes" ] && { echo "  ✓ rate limit returns 429"; PASS=$((PASS+1)); } || { echo "  ✗ no 429 seen — check RATELIMIT config"; FAIL=$((FAIL+1)); }

echo "[6] transport"
REDIR=$(code -o /dev/null "${BASE/https:/http:}/api/v1/health" 2>/dev/null || echo 000)
case "$REDIR" in
  301|302|307|308) echo "  ✓ HTTP → HTTPS redirect ($REDIR)"; PASS=$((PASS+1));;
  *) echo "  ✗ HTTP → HTTPS redirect — expected 3xx, got $REDIR"; FAIL=$((FAIL+1));;
esac

echo ""
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] && echo "VERDICT: GO ✓" || { echo "VERDICT: NO-GO ✗"; exit 1; }
