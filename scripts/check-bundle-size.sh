#!/bin/bash
# check-bundle-size.sh — Enforces web bundle size budgets in CI.
#
# Fails the build if any artifact exceeds its budget.
# Budgets are intentionally generous to catch regressions, not minor growth.

set -euo pipefail

BUILD_DIR="build/web"

# Budget limits (in bytes)
MAIN_JS_BUDGET=$((6 * 1024 * 1024))       # 6 MB for main.dart.js
CANVASKIT_BUDGET=$((8 * 1024 * 1024))      # 8 MB for canvaskit.wasm
TOTAL_BUDGET=$((40 * 1024 * 1024))         # 40 MB for entire build/web

FAILED=0

check_file() {
  local file="$1"
  local budget="$2"
  local label="$3"

  if [ ! -f "$file" ]; then
    echo "  SKIP: $label — file not found"
    return
  fi

  local size
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
  local size_mb
  size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
  local budget_mb
  budget_mb=$(echo "scale=2; $budget / 1024 / 1024" | bc)

  if [ "$size" -gt "$budget" ]; then
    echo "  FAIL: $label = ${size_mb} MB (budget: ${budget_mb} MB)"
    FAILED=1
  else
    echo "  OK:   $label = ${size_mb} MB (budget: ${budget_mb} MB)"
  fi
}

check_total() {
  local dir="$1"
  local budget="$2"

  if [ ! -d "$dir" ]; then
    echo "  SKIP: Total build — directory not found"
    return
  fi

  local size
  size=$(du -sb "$dir" 2>/dev/null | cut -f1 || du -sk "$dir" | awk '{print $1 * 1024}')
  local size_mb
  size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
  local budget_mb
  budget_mb=$(echo "scale=2; $budget / 1024 / 1024" | bc)

  if [ "$size" -gt "$budget" ]; then
    echo "  FAIL: Total build = ${size_mb} MB (budget: ${budget_mb} MB)"
    FAILED=1
  else
    echo "  OK:   Total build = ${size_mb} MB (budget: ${budget_mb} MB)"
  fi
}

echo "=== Web Bundle Size Budget Check ==="
echo ""
check_file "$BUILD_DIR/main.dart.js" "$MAIN_JS_BUDGET" "main.dart.js"
check_file "$BUILD_DIR/canvaskit/canvaskit.wasm" "$CANVASKIT_BUDGET" "canvaskit.wasm"
check_total "$BUILD_DIR" "$TOTAL_BUDGET"
echo ""

if [ "$FAILED" -eq 1 ]; then
  echo "FAILED: One or more bundles exceeded their size budget."
  echo "Action: Review recent changes for unnecessary dependencies or assets."
  exit 1
else
  echo "PASSED: All bundles within budget."
fi
