#!/bin/bash
# YMYL Checker - Your Money Your Life content requirements

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: ymyl.sh <html_file> <output_directory>"
  exit 1
fi

CHECKS=()
PASS_COUNT=0
FAIL_COUNT=0
IS_YMYL=false
YMYL_CATEGORY=""

add_check() {
  local item="$1"
  local status="$2"
  local detail="$3"

  # Escape special characters for JSON
  detail=$(echo "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r')

  if [ "$status" = "pass" ]; then
    ((PASS_COUNT++))
    CHECKS+=("{\"item\": \"$item\", \"status\": \"pass\", \"detail\": \"$detail\"}")
  else
    ((FAIL_COUNT++))
    CHECKS+=("{\"item\": \"$item\", \"status\": \"fail\", \"detail\": \"$detail\"}")
  fi
}

# YMYL keywords detection
HEALTH_KEYWORDS='醫療|健康|症狀|治療|診斷|藥物|疾病|病症|醫師|醫生|health|medical|symptom|treatment|diagnosis'
FINANCE_KEYWORDS='投資|理財|貸款|保險|稅務|財務|股票|基金|信用|finance|investment|loan|insurance|tax'
LEGAL_KEYWORDS='法律|律師|訴訟|法規|法院|legal|lawyer|lawsuit|regulation|court'

# Check if content is YMYL
if grep -qiE "$HEALTH_KEYWORDS" "$HTML_FILE"; then
  IS_YMYL=true
  YMYL_CATEGORY="health"
elif grep -qiE "$FINANCE_KEYWORDS" "$HTML_FILE"; then
  IS_YMYL=true
  YMYL_CATEGORY="finance"
elif grep -qiE "$LEGAL_KEYWORDS" "$HTML_FILE"; then
  IS_YMYL=true
  YMYL_CATEGORY="legal"
fi

if [ "$IS_YMYL" = true ]; then
  # Extract JSON-LD using awk
  JSON_LD_FILE="$OUTPUT_DIR/.ymyl-jsonld.json"
  awk '
    /<script type="application\/ld\+json">/ { capture=1; next }
    /<\/script>/ { if(capture) { capture=0; exit } }
    capture { print }
  ' "$HTML_FILE" > "$JSON_LD_FILE"

  # 1. Check lastReviewed
  LAST_REVIEWED=""
  if [ -s "$JSON_LD_FILE" ]; then
    LAST_REVIEWED=$(jq -r '.["@graph"][] | select(.["@type"] == "Article" or .["@type"] == "WebPage") | .lastReviewed // ""' "$JSON_LD_FILE" 2>/dev/null | head -1)
  fi
  if [ -n "$LAST_REVIEWED" ]; then
    add_check "lastReviewed" "pass" "$LAST_REVIEWED"
  else
    add_check "lastReviewed" "fail" "YMYL 內容需要標示最後審核日期"
  fi

  # 2. Check reviewedBy
  REVIEWED_BY=""
  if [ -s "$JSON_LD_FILE" ]; then
    REVIEWED_BY=$(jq -r '.["@graph"][] | select(.["@type"] == "Article" or .["@type"] == "WebPage") | .reviewedBy.name // ""' "$JSON_LD_FILE" 2>/dev/null | head -1)
  fi
  if [ -n "$REVIEWED_BY" ]; then
    add_check "reviewedBy" "pass" "審核者: $REVIEWED_BY"
  else
    add_check "reviewedBy" "fail" "YMYL 內容需要標示審核者"
  fi

  # 3. Check for disclaimer
  case "$YMYL_CATEGORY" in
    health)
      if grep -qi '醫療免責\|本文僅供參考\|非醫療建議\|medical disclaimer\|not medical advice' "$HTML_FILE"; then
        add_check "免責聲明" "pass" "醫療免責聲明存在"
      else
        add_check "免責聲明" "fail" "醫療內容需要免責聲明"
      fi
      ;;
    finance)
      if grep -qi '投資風險\|財務免責\|非投資建議\|investment risk\|not financial advice' "$HTML_FILE"; then
        add_check "免責聲明" "pass" "財務免責聲明存在"
      else
        add_check "免責聲明" "fail" "財務內容需要免責聲明"
      fi
      ;;
    legal)
      if grep -qi '法律免責\|非法律建議\|僅供參考\|not legal advice' "$HTML_FILE"; then
        add_check "免責聲明" "pass" "法律免責聲明存在"
      else
        add_check "免責聲明" "fail" "法律內容需要免責聲明"
      fi
      ;;
  esac

  # 4. Check for expert credentials
  HAS_CREDENTIAL=""
  if [ -s "$JSON_LD_FILE" ]; then
    HAS_CREDENTIAL=$(jq -e '.["@graph"][] | select(.["@type"] == "Person") | .hasCredential[0]' "$JSON_LD_FILE" 2>/dev/null)
  fi
  if [ -n "$HAS_CREDENTIAL" ]; then
    add_check "專業認證" "pass" "作者有專業認證"
  else
    add_check "專業認證" "fail" "YMYL 內容作者應有專業認證"
  fi

  # Cleanup
  rm -f "$JSON_LD_FILE"
fi

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

# Convert boolean to lowercase for JSON
IS_YMYL_JSON=$([ "$IS_YMYL" = true ] && echo "true" || echo "false")

cat > "$OUTPUT_DIR/ymyl-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "applicable": $IS_YMYL_JSON,
  "category": "${YMYL_CATEGORY:-none}",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "total": $TOTAL
  },
  "checks": [$CHECKS_JSON]
}
EOF
