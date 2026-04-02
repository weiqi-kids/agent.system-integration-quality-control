#!/bin/bash
# E-E-A-T Signal Checker - Experience, Expertise, Authoritativeness, Trustworthiness

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: eeat.sh <html_file> <output_directory>"
  exit 1
fi

CHECKS=()
PASS_COUNT=0
FAIL_COUNT=0

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

# Safe integer helper
safe_int() {
  local val="$1"
  local num=$(echo "$val" | tr -cd '0-9' | head -c 10)
  echo "${num:-0}"
}

# Extract JSON-LD for Person schema using awk
JSON_LD_FILE="$OUTPUT_DIR/.eeat-jsonld.json"
awk '
  /<script type="application\/ld\+json">/ { capture=1; next }
  /<\/script>/ { if(capture) { capture=0; exit } }
  capture { print }
' "$HTML_FILE" > "$JSON_LD_FILE"

# 1. Check Person Schema exists with real info
if [ -s "$JSON_LD_FILE" ] && jq -e '.["@graph"][] | select(.["@type"] == "Person")' "$JSON_LD_FILE" > /dev/null 2>&1; then
  PERSON_NAME=$(jq -r '.["@graph"][] | select(.["@type"] == "Person") | .name // ""' "$JSON_LD_FILE" 2>/dev/null)
  if [ -n "$PERSON_NAME" ]; then
    add_check "Person Schema" "pass" "作者: $PERSON_NAME"
  else
    add_check "Person Schema" "fail" "缺少作者姓名"
  fi
else
  add_check "Person Schema" "fail" "未找到 Person Schema"
fi

# 2. Check hasCredential
if [ -s "$JSON_LD_FILE" ] && jq -e '.["@graph"][] | select(.["@type"] == "Person") | .hasCredential[0]' "$JSON_LD_FILE" > /dev/null 2>&1; then
  CRED=$(jq -r '.["@graph"][] | select(.["@type"] == "Person") | .hasCredential[0].name // .hasCredential[0].credentialCategory // ""' "$JSON_LD_FILE" 2>/dev/null)
  add_check "專業認證 (hasCredential)" "pass" "$CRED"
else
  add_check "專業認證 (hasCredential)" "fail" "缺少專業認證資訊"
fi

# 3. Check sameAs (social links)
SAMEAS_COUNT=$(jq '.["@graph"][] | select(.["@type"] == "Person") | .sameAs | length // 0' "$JSON_LD_FILE" 2>/dev/null)
SAMEAS_COUNT=$(safe_int "$SAMEAS_COUNT")
if [ "$SAMEAS_COUNT" -ge 1 ]; then
  add_check "社群連結 (sameAs)" "pass" "$SAMEAS_COUNT 個連結"
else
  add_check "社群連結 (sameAs)" "fail" "需要至少 1 個社群連結"
fi

# 4. Check for high-authority external links
# Look for .gov, .edu, and academic sources
GOV_LINKS=$(grep -oE 'href="https?://[^"]*\.gov[^"]*"' "$HTML_FILE" 2>/dev/null | wc -l | tr -d ' ')
EDU_LINKS=$(grep -oE 'href="https?://[^"]*\.edu[^"]*"' "$HTML_FILE" 2>/dev/null | wc -l | tr -d ' ')

# Also check for common academic/authority domains
ACADEMIC_LINKS=$(grep -oE 'href="https?://[^"]*(pubmed|scholar\.google|doi\.org|ncbi\.nlm\.nih|who\.int|cdc\.gov|nature\.com|sciencedirect|springer|wiley|tandfonline)[^"]*"' "$HTML_FILE" 2>/dev/null | wc -l | tr -d ' ')

GOV_LINKS=$(safe_int "$GOV_LINKS")
EDU_LINKS=$(safe_int "$EDU_LINKS")
ACADEMIC_LINKS=$(safe_int "$ACADEMIC_LINKS")
AUTHORITY_TOTAL=$((GOV_LINKS + EDU_LINKS + ACADEMIC_LINKS))

if [ "$AUTHORITY_TOTAL" -ge 2 ]; then
  add_check "權威來源連結" "pass" "$AUTHORITY_TOTAL 個 (.gov: $GOV_LINKS, .edu: $EDU_LINKS, 學術: $ACADEMIC_LINKS)"
else
  add_check "權威來源連結" "fail" "需要≥2個權威來源連結 (目前: $AUTHORITY_TOTAL)"
fi

# 5. Check for author bio section
if grep -qi 'author-bio\|about-author\|作者介紹\|作者簡介' "$HTML_FILE"; then
  add_check "作者介紹區塊" "pass" "存在"
else
  add_check "作者介紹區塊" "fail" "建議新增作者介紹區塊"
fi

# 6. Check for last updated date
if grep -qi 'last-updated\|updated-date\|最後更新\|更新時間' "$HTML_FILE"; then
  add_check "更新日期標示" "pass" "存在"
else
  add_check "更新日期標示" "fail" "建議顯示最後更新日期"
fi

# Cleanup
rm -f "$JSON_LD_FILE"

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/eeat-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "total": $TOTAL
  },
  "authority_links": {
    "gov": $GOV_LINKS,
    "edu": $EDU_LINKS,
    "academic": $ACADEMIC_LINKS,
    "total": $AUTHORITY_TOTAL
  },
  "checks": [$CHECKS_JSON]
}
EOF
