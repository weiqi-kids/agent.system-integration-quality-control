#!/bin/bash
# Link Checker - Check for broken internal and external links

WEB_URL="$1"
OUTPUT_DIR="$2"

if [ -z "$WEB_URL" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: links.sh <web_url> <output_directory>"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "  Checking links on: $WEB_URL"

# Fetch the page
HTML_FILE="$OUTPUT_DIR/.page.html"
curl -sL --max-time 30 "$WEB_URL" > "$HTML_FILE" 2>/dev/null

if [ ! -s "$HTML_FILE" ]; then
  echo "  Error: Failed to fetch page"
  cat > "$OUTPUT_DIR/links-result.json" << EOF
{
  "status": "error",
  "reason": "Failed to fetch page",
  "url": "$WEB_URL"
}
EOF
  exit 1
fi

# Extract base URL for internal link detection
BASE_DOMAIN=$(echo "$WEB_URL" | sed -E 's|^https?://([^/]+).*|\1|')

# Extract all links from HTML
LINKS_FILE="$OUTPUT_DIR/.links.txt"
grep -oE 'href="[^"]+"|href='\''[^'\'']+'\''' "$HTML_FILE" | \
  sed -E 's/href=["'\''"]([^"'\'']+)["'\'']/\1/' | \
  sort -u > "$LINKS_FILE"

# Initialize counters
INTERNAL_OK=0
INTERNAL_BROKEN=0
EXTERNAL_OK=0
EXTERNAL_BROKEN=0
TOTAL_LINKS=0

# Broken links list
BROKEN_INTERNAL=""
BROKEN_EXTERNAL=""

# Check each link
while IFS= read -r link; do
  # Skip empty lines, anchors, javascript, mailto
  [[ -z "$link" ]] && continue
  [[ "$link" == "#"* ]] && continue
  [[ "$link" == "javascript:"* ]] && continue
  [[ "$link" == "mailto:"* ]] && continue
  [[ "$link" == "tel:"* ]] && continue

  ((TOTAL_LINKS++))

  # Resolve relative URLs
  if [[ "$link" == "/"* ]]; then
    FULL_URL="https://$BASE_DOMAIN$link"
    IS_INTERNAL=true
  elif [[ "$link" == "http"* ]]; then
    FULL_URL="$link"
    if [[ "$link" == *"$BASE_DOMAIN"* ]]; then
      IS_INTERNAL=true
    else
      IS_INTERNAL=false
    fi
  else
    # Relative path
    FULL_URL="$WEB_URL/$link"
    IS_INTERNAL=true
  fi

  # Check HTTP status (with timeout)
  HTTP_STATUS=$(curl -sI --max-time 10 -o /dev/null -w "%{http_code}" "$FULL_URL" 2>/dev/null)

  # Evaluate status
  if [[ "$HTTP_STATUS" =~ ^[23] ]]; then
    # 2xx or 3xx = OK
    if $IS_INTERNAL; then
      ((INTERNAL_OK++))
    else
      ((EXTERNAL_OK++))
    fi
  else
    # 4xx, 5xx, or timeout = Broken
    if $IS_INTERNAL; then
      ((INTERNAL_BROKEN++))
      BROKEN_INTERNAL="$BROKEN_INTERNAL{\"url\": \"$FULL_URL\", \"status\": \"$HTTP_STATUS\"},"
    else
      ((EXTERNAL_BROKEN++))
      BROKEN_EXTERNAL="$BROKEN_EXTERNAL{\"url\": \"$FULL_URL\", \"status\": \"$HTTP_STATUS\"},"
    fi
  fi

  # Progress indicator
  if [ $((TOTAL_LINKS % 10)) -eq 0 ]; then
    echo -n "."
  fi
done < "$LINKS_FILE"

echo ""

# Remove trailing commas
BROKEN_INTERNAL="${BROKEN_INTERNAL%,}"
BROKEN_EXTERNAL="${BROKEN_EXTERNAL%,}"

# Calculate totals
TOTAL_BROKEN=$((INTERNAL_BROKEN + EXTERNAL_BROKEN))
TOTAL_OK=$((INTERNAL_OK + EXTERNAL_OK))

# Generate result
cat > "$OUTPUT_DIR/links-result.json" << EOF
{
  "status": "completed",
  "url": "$WEB_URL",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "total_links": $TOTAL_LINKS,
    "ok": $TOTAL_OK,
    "broken": $TOTAL_BROKEN
  },
  "internal": {
    "ok": $INTERNAL_OK,
    "broken": $INTERNAL_BROKEN
  },
  "external": {
    "ok": $EXTERNAL_OK,
    "broken": $EXTERNAL_BROKEN
  },
  "broken_links": {
    "internal": [$BROKEN_INTERNAL],
    "external": [$BROKEN_EXTERNAL]
  }
}
EOF

# Cleanup temp files
rm -f "$HTML_FILE" "$LINKS_FILE"

echo "  Link check completed: $TOTAL_OK OK, $TOTAL_BROKEN broken (Internal: $INTERNAL_BROKEN, External: $EXTERNAL_BROKEN)"
