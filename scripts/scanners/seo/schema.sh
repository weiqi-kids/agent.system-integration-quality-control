#!/bin/bash
# Schema Checker - Check for JSON-LD structured data

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: schema.sh <html_file> <output_directory>"
  exit 1
fi

# Extract JSON-LD from HTML using awk (works on macOS and Linux)
JSON_LD_FILE="$OUTPUT_DIR/.jsonld.json"
awk '
  /<script type="application\/ld\+json">/ { capture=1; next }
  /<\/script>/ { if(capture) { capture=0; exit } }
  capture { print }
' "$HTML_FILE" > "$JSON_LD_FILE"

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

# Safe integer comparison helper
safe_int() {
  local val="$1"
  echo "$val" | tr -cd '0-9' | head -c 10
}

# Check if JSON-LD exists
if [ ! -s "$JSON_LD_FILE" ]; then
  add_check "JSON-LD" "fail" "未找到 JSON-LD 結構化資料"
else
  # Validate JSON
  if ! jq -e . "$JSON_LD_FILE" > /dev/null 2>&1; then
    add_check "JSON-LD 語法" "fail" "JSON 語法錯誤"
  else
    add_check "JSON-LD 語法" "pass" "語法正確"

    # Check for @graph or single schema
    HAS_GRAPH=$(jq -e '.["@graph"]' "$JSON_LD_FILE" 2>/dev/null)

    # Helper function to check schema
    check_schema() {
      local type="$1"

      if [ -n "$HAS_GRAPH" ]; then
        SCHEMA=$(jq -c ".\"@graph\"[] | select(.\"@type\" == \"$type\")" "$JSON_LD_FILE" 2>/dev/null)
      else
        SCHEMA=$(jq -c "select(.\"@type\" == \"$type\")" "$JSON_LD_FILE" 2>/dev/null)
      fi

      if [ -n "$SCHEMA" ]; then
        add_check "$type Schema" "pass" "存在"
        return 0
      else
        add_check "$type Schema" "fail" "缺少"
        return 1
      fi
    }

    # 1. WebPage Schema
    if check_schema "WebPage"; then
      SPEAKABLE=$(jq '.["@graph"][] | select(.["@type"] == "WebPage") | .speakable.cssSelector | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      SPEAKABLE=$(safe_int "$SPEAKABLE")
      SPEAKABLE=${SPEAKABLE:-0}
      if [ "$SPEAKABLE" -ge 7 ]; then
        add_check "WebPage.speakable" "pass" "$SPEAKABLE 個 cssSelector"
      else
        add_check "WebPage.speakable" "fail" "需要≥7個 cssSelector"
      fi
    fi

    # 2. Article Schema
    if check_schema "Article"; then
      # Check isAccessibleForFree
      FREE=$(jq -r '.["@graph"][] | select(.["@type"] == "Article") | .isAccessibleForFree // ""' "$JSON_LD_FILE" 2>/dev/null)
      if [ "$FREE" = "true" ] || [ "$FREE" = "false" ]; then
        add_check "Article.isAccessibleForFree" "pass" "$FREE"
      else
        add_check "Article.isAccessibleForFree" "fail" "缺少"
      fi

      # Check isPartOf with SearchAction
      ISPARTOF=$(jq -c '.["@graph"][] | select(.["@type"] == "Article") | .isPartOf // empty' "$JSON_LD_FILE" 2>/dev/null)
      if [ -n "$ISPARTOF" ]; then
        add_check "Article.isPartOf" "pass" "存在"
      else
        add_check "Article.isPartOf" "fail" "缺少"
      fi

      # Check significantLink
      SIGLINK=$(jq '.["@graph"][] | select(.["@type"] == "Article") | .significantLink | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      SIGLINK=$(safe_int "$SIGLINK")
      SIGLINK=${SIGLINK:-0}
      if [ "$SIGLINK" -ge 2 ]; then
        add_check "Article.significantLink" "pass" "$SIGLINK 個連結"
      else
        add_check "Article.significantLink" "fail" "需要≥2個相關文章連結"
      fi
    fi

    # 3. Person Schema
    if check_schema "Person"; then
      # Check knowsAbout
      KNOWS=$(jq '.["@graph"][] | select(.["@type"] == "Person") | .knowsAbout | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      KNOWS=$(safe_int "$KNOWS")
      KNOWS=${KNOWS:-0}
      if [ "$KNOWS" -ge 2 ]; then
        add_check "Person.knowsAbout" "pass" "$KNOWS 項"
      else
        add_check "Person.knowsAbout" "fail" "需要≥2項專業領域"
      fi

      # Check hasCredential
      CRED=$(jq '.["@graph"][] | select(.["@type"] == "Person") | .hasCredential | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      CRED=$(safe_int "$CRED")
      CRED=${CRED:-0}
      if [ "$CRED" -ge 1 ]; then
        add_check "Person.hasCredential" "pass" "$CRED 個認證"
      else
        add_check "Person.hasCredential" "fail" "需要≥1個專業認證"
      fi

      # Check sameAs
      SAMEAS=$(jq '.["@graph"][] | select(.["@type"] == "Person") | .sameAs | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      SAMEAS=$(safe_int "$SAMEAS")
      SAMEAS=${SAMEAS:-0}
      if [ "$SAMEAS" -ge 1 ]; then
        add_check "Person.sameAs" "pass" "$SAMEAS 個社群連結"
      else
        add_check "Person.sameAs" "fail" "需要≥1個社群連結"
      fi
    fi

    # 4. Organization Schema
    if check_schema "Organization"; then
      # Check contactPoint
      CONTACT=$(jq -c '.["@graph"][] | select(.["@type"] == "Organization") | .contactPoint // empty' "$JSON_LD_FILE" 2>/dev/null)
      if [ -n "$CONTACT" ]; then
        add_check "Organization.contactPoint" "pass" "存在"
      else
        add_check "Organization.contactPoint" "fail" "缺少聯絡資訊"
      fi

      # Check logo with dimensions
      LOGO=$(jq -c '.["@graph"][] | select(.["@type"] == "Organization") | .logo // empty' "$JSON_LD_FILE" 2>/dev/null)
      if [ -n "$LOGO" ]; then
        add_check "Organization.logo" "pass" "存在"
      else
        add_check "Organization.logo" "fail" "缺少 logo"
      fi
    fi

    # 5. BreadcrumbList Schema
    check_schema "BreadcrumbList"

    # 6. FAQPage Schema
    if check_schema "FAQPage"; then
      FAQ_COUNT=$(jq '.["@graph"][] | select(.["@type"] == "FAQPage") | .mainEntity | length // 0' "$JSON_LD_FILE" 2>/dev/null)
      FAQ_COUNT=$(safe_int "$FAQ_COUNT")
      FAQ_COUNT=${FAQ_COUNT:-0}
      if [ "$FAQ_COUNT" -ge 3 ] && [ "$FAQ_COUNT" -le 5 ]; then
        add_check "FAQPage.mainEntity" "pass" "$FAQ_COUNT 個 Q&A"
      else
        add_check "FAQPage.mainEntity" "fail" "需要 3-5 個 Q&A"
      fi
    fi

    # 7. ImageObject Schema
    if check_schema "ImageObject"; then
      LICENSE=$(jq -r '.["@graph"][] | select(.["@type"] == "ImageObject") | .license // ""' "$JSON_LD_FILE" 2>/dev/null)
      if [ -n "$LICENSE" ]; then
        add_check "ImageObject.license" "pass" "存在"
      else
        add_check "ImageObject.license" "fail" "缺少授權資訊"
      fi

      CREDIT=$(jq -r '.["@graph"][] | select(.["@type"] == "ImageObject") | .creditText // ""' "$JSON_LD_FILE" 2>/dev/null)
      if [ -n "$CREDIT" ]; then
        add_check "ImageObject.creditText" "pass" "存在"
      else
        add_check "ImageObject.creditText" "fail" "缺少署名"
      fi
    fi

    # Conditional Schemas - check based on content
    # HowTo
    if grep -q '<ol' "$HTML_FILE" && grep -qi '步驟\|step' "$HTML_FILE"; then
      check_schema "HowTo"
    fi

    # VideoObject
    if grep -qi 'youtube\|vimeo\|<video' "$HTML_FILE"; then
      check_schema "VideoObject"
    fi

    # ItemList
    if grep -qi '大\|TOP\|排名\|排行' "$HTML_FILE"; then
      check_schema "ItemList"
    fi

    # Review
    if grep -qi '評測\|開箱\|review' "$HTML_FILE"; then
      check_schema "Review"
    fi
  fi
fi

# Cleanup
rm -f "$JSON_LD_FILE"

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/schema-result.json" << EOF
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
