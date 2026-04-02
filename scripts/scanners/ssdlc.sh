#!/bin/bash
# SSDLC Check - Secure Software Development Lifecycle checks

TARGET_DIR="$1"
OUTPUT_DIR="$2"

if [ -z "$TARGET_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: ssdlc.sh <target_directory> <output_directory>"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "  Running SSDLC checks..."

cd "$TARGET_DIR"

# Initialize checks array
CHECKS=()
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"

  CHECKS+=("{\"name\": \"$name\", \"status\": \"$status\", \"detail\": \"$detail\"}")

  case $status in
    PASS) ((PASS_COUNT++)) ;;
    FAIL) ((FAIL_COUNT++)) ;;
    WARN) ((WARN_COUNT++)) ;;
  esac
}

# 1. Check for .gitignore
if [ -f .gitignore ]; then
  add_check "版本控制忽略設定" "PASS" "已設定 .gitignore"
else
  add_check "版本控制忽略設定" "FAIL" "缺少 .gitignore"
fi

# 2. Check for README
if [ -f README.md ] || [ -f README.rst ] || [ -f README ]; then
  add_check "專案文件" "PASS" "已有 README"
else
  add_check "專案文件" "FAIL" "缺少 README"
fi

# 3. Check for LICENSE
if [ -f LICENSE ] || [ -f LICENSE.md ] || [ -f LICENSE.txt ]; then
  add_check "授權聲明" "PASS" "已有 LICENSE"
else
  add_check "授權聲明" "WARN" "缺少 LICENSE"
fi

# 4. Check for CI/CD
if [ -d .github/workflows ] || [ -f .gitlab-ci.yml ] || [ -f Jenkinsfile ] || [ -f .circleci/config.yml ]; then
  add_check "CI/CD 設定" "PASS" "已設定 CI/CD"
else
  add_check "CI/CD 設定" "WARN" "未發現 CI/CD 設定"
fi

# 5. Check for SECURITY.md
if [ -f SECURITY.md ] || [ -f .github/SECURITY.md ]; then
  add_check "安全政策" "PASS" "已有 SECURITY.md"
else
  add_check "安全政策" "WARN" "建議新增 SECURITY.md"
fi

# 6. Check for dependency lock files
if [ -f package-lock.json ] || [ -f yarn.lock ] || [ -f pnpm-lock.yaml ] || \
   [ -f Pipfile.lock ] || [ -f poetry.lock ] || [ -f Gemfile.lock ] || [ -f go.sum ]; then
  add_check "依賴版本鎖定" "PASS" "已有鎖定檔"
else
  add_check "依賴版本鎖定" "WARN" "建議使用依賴鎖定檔"
fi

# 7. Check Dockerfile for non-root user
if [ -f Dockerfile ]; then
  if grep -q "^USER" Dockerfile; then
    add_check "Docker 非 root 用戶" "PASS" "已設定 USER"
  else
    add_check "Docker 非 root 用戶" "WARN" "建議設定非 root USER"
  fi
fi

# 8. Check for sensitive files
SECRETS_FOUND=""
for pattern in ".env" "*.pem" "*.key" "credentials*" "*secret*" "*password*"; do
  FOUND=$(find . -name "$pattern" -type f 2>/dev/null | grep -v node_modules | grep -v ".git" | head -5)
  if [ -n "$FOUND" ]; then
    SECRETS_FOUND="$SECRETS_FOUND $FOUND"
  fi
done

if [ -n "$SECRETS_FOUND" ]; then
  # Escape for JSON
  SECRETS_ESCAPED=$(echo "$SECRETS_FOUND" | tr '\n' ' ' | sed 's/"/\\"/g')
  add_check "敏感檔案檢查" "FAIL" "發現可能的敏感檔案:$SECRETS_ESCAPED"
else
  add_check "敏感檔案檢查" "PASS" "未發現明顯敏感檔案"
fi

# 9. Check for hardcoded passwords in code
HARDCODED=$(grep -rn "password\s*=\s*['\"]" --include="*.py" --include="*.js" --include="*.ts" --include="*.java" --include="*.go" . 2>/dev/null | grep -v node_modules | grep -v ".git" | head -3)
if [ -n "$HARDCODED" ]; then
  add_check "硬編碼密碼檢查" "FAIL" "發現疑似硬編碼密碼"
else
  add_check "硬編碼密碼檢查" "PASS" "未發現明顯硬編碼密碼"
fi

# 10. Check for code owners
if [ -f CODEOWNERS ] || [ -f .github/CODEOWNERS ]; then
  add_check "程式碼擁有者" "PASS" "已設定 CODEOWNERS"
else
  add_check "程式碼擁有者" "WARN" "建議設定 CODEOWNERS"
fi

# Run Checkov if available
CHECKOV_PASSED=0
CHECKOV_FAILED=0
if command -v checkov &> /dev/null; then
  echo "  Running Checkov IaC scan..."
  checkov -d . --output json > "$OUTPUT_DIR/checkov-report.json" 2>/dev/null || true

  if [ -f "$OUTPUT_DIR/checkov-report.json" ]; then
    CHECKOV_PASSED=$(jq '.results.passed_checks | length' "$OUTPUT_DIR/checkov-report.json" 2>/dev/null || echo "0")
    CHECKOV_FAILED=$(jq '.results.failed_checks | length' "$OUTPUT_DIR/checkov-report.json" 2>/dev/null || echo "0")
  fi
fi

# Build JSON output
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/ssdlc-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "warn": $WARN_COUNT,
    "total": $((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
  },
  "checkov": {
    "passed": $CHECKOV_PASSED,
    "failed": $CHECKOV_FAILED
  },
  "checks": [$CHECKS_JSON]
}
EOF

echo "  SSDLC check completed: $PASS_COUNT passed, $FAIL_COUNT failed, $WARN_COUNT warnings"
