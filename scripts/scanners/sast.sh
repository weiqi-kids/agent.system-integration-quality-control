#!/bin/bash
# SAST Scanner - Static Application Security Testing using Semgrep

TARGET_DIR="$1"
OUTPUT_DIR="$2"

if [ -z "$TARGET_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: sast.sh <target_directory> <output_directory>"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "  Running Semgrep SAST scan..."

# Check if semgrep is available
if ! command -v semgrep &> /dev/null; then
  echo "  Warning: semgrep is not installed, skipping SAST scan"
  cat > "$OUTPUT_DIR/sast-result.json" << EOF
{
  "status": "skipped",
  "reason": "semgrep not installed",
  "results": [],
  "errors": []
}
EOF
  exit 0
fi

# Run Semgrep with security rules
cd "$TARGET_DIR"

# JSON output
semgrep scan \
  --config=auto \
  --json \
  --output="$OUTPUT_DIR/semgrep-report.json" \
  . 2>/dev/null || true

# Text output for readability
semgrep scan \
  --config=auto \
  --text \
  --output="$OUTPUT_DIR/semgrep-report.txt" \
  . 2>/dev/null || true

# Generate summary
if [ -f "$OUTPUT_DIR/semgrep-report.json" ]; then
  FINDINGS=$(jq '.results | length' "$OUTPUT_DIR/semgrep-report.json" 2>/dev/null || echo "0")
  ERRORS=$(jq '.errors | length' "$OUTPUT_DIR/semgrep-report.json" 2>/dev/null || echo "0")

  # Count by severity
  CRITICAL=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$OUTPUT_DIR/semgrep-report.json" 2>/dev/null || echo "0")
  HIGH=$(jq '[.results[] | select(.extra.severity == "WARNING")] | length' "$OUTPUT_DIR/semgrep-report.json" 2>/dev/null || echo "0")
  MEDIUM=$(jq '[.results[] | select(.extra.severity == "INFO")] | length' "$OUTPUT_DIR/semgrep-report.json" 2>/dev/null || echo "0")

  cat > "$OUTPUT_DIR/sast-result.json" << EOF
{
  "status": "completed",
  "tool": "semgrep",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "total_findings": $FINDINGS,
    "critical": $CRITICAL,
    "high": $HIGH,
    "medium": $MEDIUM,
    "errors": $ERRORS
  }
}
EOF

  echo "  SAST scan completed: $FINDINGS findings"
else
  cat > "$OUTPUT_DIR/sast-result.json" << EOF
{
  "status": "error",
  "reason": "No output generated",
  "results": []
}
EOF
  echo "  SAST scan failed: no output generated"
fi
