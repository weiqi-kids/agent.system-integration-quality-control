#!/bin/bash
# Meta Tags Checker - Check for SEO meta tags

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: meta.sh <html_file> <output_directory>"
  exit 1
fi

CHECKS=()
PASS_COUNT=0
FAIL_COUNT=0

add_check() {
  local item="$1"
  local status="$2"
  local value="$3"
  local expected="$4"

  # Escape special characters for JSON
  value=$(echo "$value" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r')
  expected=$(echo "$expected" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r')

  if [ "$status" = "pass" ]; then
    ((PASS_COUNT++))
    CHECKS+=("{\"item\": \"$item\", \"status\": \"pass\", \"value\": \"$value\"}")
  else
    ((FAIL_COUNT++))
    CHECKS+=("{\"item\": \"$item\", \"status\": \"fail\", \"expected\": \"$expected\", \"actual\": \"$value\"}")
  fi
}

# Helper function to extract meta content
extract_meta() {
  local attr="$1"
  local value="$2"
  # Try double quotes first, then single quotes
  local result=$(sed -n "s/.*$attr=\"$value\"[^>]*content=\"\([^\"]*\)\".*/\1/p" "$HTML_FILE" | head -1)
  if [ -z "$result" ]; then
    result=$(sed -n "s/.*content=\"\([^\"]*\)\"[^>]*$attr=\"$value\".*/\1/p" "$HTML_FILE" | head -1)
  fi
  echo "$result"
}

# 1. Check <title>
TITLE=$(sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' "$HTML_FILE" | head -1)
TITLE_LEN=${#TITLE}
if [ -n "$TITLE" ] && [ "$TITLE_LEN" -le 60 ]; then
  add_check "title" "pass" "$TITLE" ""
else
  add_check "title" "fail" "$TITLE" "存在且≤60字"
fi

# 2. Check meta description
DESC=$(extract_meta "name" "description")
DESC_LEN=${#DESC}
if [ -n "$DESC" ] && [ "$DESC_LEN" -le 155 ]; then
  add_check "description" "pass" "${DESC:0:50}..." ""
else
  add_check "description" "fail" "${DESC:0:30}..." "存在且≤155字"
fi

# 3. Check og:title
OG_TITLE=$(extract_meta "property" "og:title")
if [ -n "$OG_TITLE" ]; then
  add_check "og:title" "pass" "${OG_TITLE:0:40}..." ""
else
  add_check "og:title" "fail" "" "必須存在"
fi

# 4. Check og:description
OG_DESC=$(extract_meta "property" "og:description")
if [ -n "$OG_DESC" ]; then
  add_check "og:description" "pass" "${OG_DESC:0:40}..." ""
else
  add_check "og:description" "fail" "" "必須存在"
fi

# 5. Check og:image
OG_IMAGE=$(extract_meta "property" "og:image")
if [ -n "$OG_IMAGE" ]; then
  add_check "og:image" "pass" "$OG_IMAGE" ""
else
  add_check "og:image" "fail" "" "必須存在"
fi

# 6. Check og:url
OG_URL=$(extract_meta "property" "og:url")
if [ -n "$OG_URL" ]; then
  add_check "og:url" "pass" "$OG_URL" ""
else
  add_check "og:url" "fail" "" "必須存在"
fi

# 7. Check og:type
OG_TYPE=$(extract_meta "property" "og:type")
if [ "$OG_TYPE" = "article" ]; then
  add_check "og:type" "pass" "$OG_TYPE" ""
else
  add_check "og:type" "fail" "$OG_TYPE" "article"
fi

# 8. Check article:published_time
PUB_TIME=$(extract_meta "property" "article:published_time")
if [ -n "$PUB_TIME" ] && [[ "$PUB_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
  add_check "article:published_time" "pass" "$PUB_TIME" ""
else
  add_check "article:published_time" "fail" "$PUB_TIME" "ISO 8601 格式"
fi

# 9. Check article:modified_time
MOD_TIME=$(extract_meta "property" "article:modified_time")
if [ -n "$MOD_TIME" ] && [[ "$MOD_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
  add_check "article:modified_time" "pass" "$MOD_TIME" ""
else
  add_check "article:modified_time" "fail" "$MOD_TIME" "ISO 8601 格式"
fi

# 10. Check twitter:card
TW_CARD=$(extract_meta "name" "twitter:card")
if [ "$TW_CARD" = "summary_large_image" ]; then
  add_check "twitter:card" "pass" "$TW_CARD" ""
else
  add_check "twitter:card" "fail" "$TW_CARD" "summary_large_image"
fi

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/meta-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "total": $TOTAL
  },
  "checks": [$CHECKS_JSON]
}
EOF
