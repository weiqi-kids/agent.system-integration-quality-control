#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")}"

# Generate scan ID
SCAN_ID=$(date '+%Y%m%d-%H%M%S')
SCAN_DIR="$PROJECT_ROOT/docs/scans/$SCAN_ID"
WORK_DIR="$PROJECT_ROOT/.work"

mkdir -p "$SCAN_DIR"
mkdir -p "$WORK_DIR"

echo "Scan ID: $SCAN_ID"
echo "Scan directory: $SCAN_DIR"
echo ""

# Initialize scan metadata
cat > "$SCAN_DIR/metadata.json" << EOF
{
  "scan_id": "$SCAN_ID",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "project_name": "$PROJECT_NAME",
  "web_url": "$WEB_URL",
  "scan_depth": "$SCAN_DEPTH",
  "repos": ${REPOS_JSON:-[]},
  "projects": []
}
EOF

# Track overall status
SCAN_FAILED=false
SCANNED_PROJECTS=()

# 1. Scan each repo sequentially
if [ -n "$REPOS_JSON" ] && [ "$REPOS_JSON" != "[]" ]; then
echo "========================================"
echo "  Scanning repositories"
echo "========================================"

echo "$REPOS_JSON" | jq -r '.[]' | while read -r repo_url; do
  echo ""
  echo "----------------------------------------"
  echo "Repository: $repo_url"
  echo "----------------------------------------"

  # Extract project name from URL
  project_name=$(basename "$repo_url" .git)
  project_dir="$WORK_DIR/target-$project_name"
  report_dir="$SCAN_DIR/$project_name"

  mkdir -p "$report_dir"

  # Clone repository
  echo "Cloning repository..."
  if [ -n "$PAT_TOKEN" ]; then
    AUTH_URL=$(echo "$repo_url" | sed "s|https://|https://$PAT_TOKEN@|")
  else
    AUTH_URL="$repo_url"
  fi

  if git clone --depth 1 "$AUTH_URL" "$project_dir" 2>/dev/null; then
    echo "Clone successful"

    # Run scans
    echo "Running SAST scan..."
    "$SCRIPT_DIR/scanners/sast.sh" "$project_dir" "$report_dir" || echo "SAST scan completed with errors"

    echo "Running vulnerability scan..."
    "$SCRIPT_DIR/scanners/vulnerability.sh" "$project_dir" "$report_dir" || echo "Vulnerability scan completed with errors"

    echo "Running SSDLC check..."
    "$SCRIPT_DIR/scanners/ssdlc.sh" "$project_dir" "$report_dir" || echo "SSDLC check completed with errors"

    # Generate project report
    echo "Generating project report..."
    "$SCRIPT_DIR/report/generate-project-report.sh" "$project_name" "$repo_url" "$report_dir"

    # Cleanup
    rm -rf "$project_dir"

    echo "Completed: $project_name"
  else
    echo "ERROR: Failed to clone $repo_url"
    echo "FAIL: Cannot clone $repo_url" >> "$SCAN_DIR/errors.log"

    # Create error report for this project
    cat > "$report_dir/error.json" << EOF
{
  "project": "$project_name",
  "repo_url": "$repo_url",
  "error": "Failed to clone repository",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
    SCAN_FAILED=true
  fi
done
fi  # end if REPOS_JSON

# 2. Web URL scans (pentest + SEO)
if [ -n "$WEB_URL" ]; then
  echo ""
  echo "========================================"
  echo "  Running penetration test"
  echo "========================================"
  echo "Target: $WEB_URL"

  mkdir -p "$SCAN_DIR/pentest"
  "$SCRIPT_DIR/scanners/pentest.sh" "$WEB_URL" "$SCAN_DIR/pentest" || {
    echo "Penetration test completed with errors"
  }

  echo ""
  echo "========================================"
  echo "  Running SEO/AEO checks"
  echo "========================================"
  echo "Target: $WEB_URL"

  mkdir -p "$SCAN_DIR/seo"

  # Link check
  echo "Checking links..."
  "$SCRIPT_DIR/scanners/links.sh" "$WEB_URL" "$SCAN_DIR/seo" || {
    echo "Link check completed with errors"
  }

  # SEO checks (Meta, Schema, SGE, E-E-A-T, CWV, YMYL)
  echo "Running SEO checks..."
  "$SCRIPT_DIR/scanners/seo.sh" "$WEB_URL" "$SCAN_DIR/seo" || {
    echo "SEO check completed with errors"
  }
fi

# 3. Generate index report
echo ""
echo "========================================"
echo "  Generating reports"
echo "========================================"

"$SCRIPT_DIR/report/generate-index.sh" "$SCAN_DIR"

# Cleanup work directory
rm -rf "$WORK_DIR"

# Check for errors
if [ -f "$SCAN_DIR/errors.log" ]; then
  echo ""
  echo "========================================"
  echo "  Errors occurred during scan"
  echo "========================================"
  cat "$SCAN_DIR/errors.log"
  exit 1
fi

echo ""
echo "All scans completed successfully!"
