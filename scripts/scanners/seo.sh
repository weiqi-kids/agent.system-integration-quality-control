#!/bin/bash
# SEO Scanner - Integrated SEO/AEO checks

WEB_URL="$1"
OUTPUT_DIR="$2"

if [ -z "$WEB_URL" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: seo.sh <web_url> <output_directory>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$OUTPUT_DIR"

echo "  Running SEO/AEO checks on: $WEB_URL"

# Fetch the page once and cache it
HTML_FILE="$OUTPUT_DIR/.page.html"
curl -sL --max-time 30 "$WEB_URL" > "$HTML_FILE" 2>/dev/null

if [ ! -s "$HTML_FILE" ]; then
  echo "  Error: Failed to fetch page"
  cat > "$OUTPUT_DIR/seo-result.json" << EOF
{
  "status": "error",
  "reason": "Failed to fetch page",
  "url": "$WEB_URL"
}
EOF
  exit 1
fi

# Export for sub-scripts
export HTML_FILE WEB_URL OUTPUT_DIR

# Run all SEO checks
echo "  Checking Meta tags..."
"$SCRIPT_DIR/seo/meta.sh" "$HTML_FILE" "$OUTPUT_DIR"

echo "  Checking Schema markup..."
"$SCRIPT_DIR/seo/schema.sh" "$HTML_FILE" "$OUTPUT_DIR"

echo "  Checking SGE/AEO markers..."
"$SCRIPT_DIR/seo/sge.sh" "$HTML_FILE" "$OUTPUT_DIR"

echo "  Checking E-E-A-T signals..."
"$SCRIPT_DIR/seo/eeat.sh" "$HTML_FILE" "$OUTPUT_DIR"

echo "  Checking Core Web Vitals indicators..."
"$SCRIPT_DIR/seo/cwv.sh" "$HTML_FILE" "$OUTPUT_DIR"

echo "  Checking YMYL requirements..."
"$SCRIPT_DIR/seo/ymyl.sh" "$HTML_FILE" "$OUTPUT_DIR"

# Aggregate results
echo "  Generating SEO summary..."

META_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/meta-result.json" 2>/dev/null || echo "0")
META_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/meta-result.json" 2>/dev/null || echo "0")

SCHEMA_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/schema-result.json" 2>/dev/null || echo "0")
SCHEMA_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/schema-result.json" 2>/dev/null || echo "0")

SGE_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/sge-result.json" 2>/dev/null || echo "0")
SGE_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/sge-result.json" 2>/dev/null || echo "0")

EEAT_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/eeat-result.json" 2>/dev/null || echo "0")
EEAT_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/eeat-result.json" 2>/dev/null || echo "0")

CWV_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/cwv-result.json" 2>/dev/null || echo "0")
CWV_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/cwv-result.json" 2>/dev/null || echo "0")

YMYL_PASS=$(jq '.summary.pass // 0' "$OUTPUT_DIR/ymyl-result.json" 2>/dev/null || echo "0")
YMYL_TOTAL=$(jq '.summary.total // 0' "$OUTPUT_DIR/ymyl-result.json" 2>/dev/null || echo "0")
YMYL_APPLICABLE=$(jq '.applicable // false' "$OUTPUT_DIR/ymyl-result.json" 2>/dev/null || echo "false")

TOTAL_PASS=$((META_PASS + SCHEMA_PASS + SGE_PASS + EEAT_PASS + CWV_PASS))
TOTAL_CHECKS=$((META_TOTAL + SCHEMA_TOTAL + SGE_TOTAL + EEAT_TOTAL + CWV_TOTAL))

if [ "$YMYL_APPLICABLE" = "true" ]; then
  TOTAL_PASS=$((TOTAL_PASS + YMYL_PASS))
  TOTAL_CHECKS=$((TOTAL_CHECKS + YMYL_TOTAL))
fi

# Generate aggregated result
cat > "$OUTPUT_DIR/seo-result.json" << EOF
{
  "status": "completed",
  "url": "$WEB_URL",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $TOTAL_PASS,
    "total": $TOTAL_CHECKS,
    "score": $(echo "scale=0; $TOTAL_PASS * 100 / $TOTAL_CHECKS" | bc 2>/dev/null || echo "0")
  },
  "categories": {
    "meta": {"pass": $META_PASS, "total": $META_TOTAL},
    "schema": {"pass": $SCHEMA_PASS, "total": $SCHEMA_TOTAL},
    "sge": {"pass": $SGE_PASS, "total": $SGE_TOTAL},
    "eeat": {"pass": $EEAT_PASS, "total": $EEAT_TOTAL},
    "cwv": {"pass": $CWV_PASS, "total": $CWV_TOTAL},
    "ymyl": {"pass": $YMYL_PASS, "total": $YMYL_TOTAL, "applicable": $YMYL_APPLICABLE}
  }
}
EOF

# Cleanup
rm -f "$HTML_FILE"

echo "  SEO check completed: $TOTAL_PASS/$TOTAL_CHECKS passed"
