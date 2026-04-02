#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 參數解析（支援環境變數或 CLI 參數）
REPOS_JSON="${REPOS_JSON:-$1}"
WEB_URL="${WEB_URL:-$2}"
SCAN_DEPTH="${SCAN_DEPTH:-${3:-standard}}"
SKIP_SETUP="${SKIP_SETUP:-false}"
PROJECT_NAME="${PROJECT_NAME:-$4}"

# PROJECT_NAME fallback: WEB_URL domain → first repo basename → "unknown"
if [ -z "$PROJECT_NAME" ]; then
  if [ -n "$WEB_URL" ]; then
    PROJECT_NAME=$(echo "$WEB_URL" | sed -E 's|https?://||; s|/.*||; s|:.*||')
  fi
fi
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(echo "$REPOS_JSON" | jq -r '.[0] // ""' 2>/dev/null | xargs basename 2>/dev/null | sed 's/\.git$//')
fi
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="unknown"
fi

# Sanitize: lowercase, filesystem-safe
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//')

# 顯示設定
echo "========================================"
echo "  System Integration Quality Control"
echo "========================================"
echo ""
echo "REPOS_JSON: $REPOS_JSON"
echo "WEB_URL: ${WEB_URL:-"(not specified)"}"
echo "SCAN_DEPTH: $SCAN_DEPTH"
echo "SKIP_SETUP: $SKIP_SETUP"
echo "PROJECT_NAME: $PROJECT_NAME"
echo ""

# 驗證必要參數（至少需要 REPOS_JSON 或 WEB_URL）
if [ -z "$REPOS_JSON" ] && [ -z "$WEB_URL" ]; then
  echo "Error: At least one of REPOS_JSON or WEB_URL is required"
  echo ""
  echo "Usage:"
  echo "  ./scripts/entrypoint.sh '[\"https://github.com/owner/repo\"]' 'https://web.url'"
  echo ""
  echo "Or with environment variables:"
  echo "  export REPOS_JSON='[\"https://github.com/owner/repo\"]'"
  echo "  export WEB_URL='https://web.url'"
  echo "  export PROJECT_NAME='my-project'  # optional"
  echo "  ./scripts/entrypoint.sh"
  exit 1
fi

# 驗證 JSON 格式（僅在有提供 REPOS_JSON 時）
if [ -n "$REPOS_JSON" ] && ! echo "$REPOS_JSON" | jq -e . > /dev/null 2>&1; then
  echo "Error: REPOS_JSON is not valid JSON"
  echo "Expected format: [\"https://github.com/owner/repo1\", \"https://github.com/owner/repo2\"]"
  exit 1
fi

# 安裝工具（可跳過）
if [ "$SKIP_SETUP" != "true" ]; then
  echo "Installing tools..."
  "$SCRIPT_DIR/setup-tools.sh"
else
  echo "Skipping tool setup (SKIP_SETUP=true)"
fi

# 執行掃描
echo ""
echo "Starting scans..."
export REPOS_JSON WEB_URL SCAN_DEPTH PROJECT_ROOT PROJECT_NAME
"$SCRIPT_DIR/scan-all.sh"

echo ""
echo "========================================"
echo "  Scan completed!"
echo "========================================"
echo ""
echo "Reports are available in: docs/scans/"
echo ""
echo "To deploy to GitHub:"
echo "  git add docs/"
echo "  git commit -m \"Add scan report \$(date '+%Y%m%d-%H%M%S')\""
echo "  git push origin main"
