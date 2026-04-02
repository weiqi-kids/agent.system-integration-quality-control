#!/bin/bash
# Generate detailed HTML report for a single project

PROJECT_NAME="$1"
REPO_URL="$2"
REPORT_DIR="$3"

if [ -z "$PROJECT_NAME" ] || [ -z "$REPO_URL" ] || [ -z "$REPORT_DIR" ]; then
  echo "Usage: generate-project-report.sh <project_name> <repo_url> <report_directory>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATE="$PROJECT_ROOT/templates/project-report.html"

# Read scan results
SAST_RESULT="$REPORT_DIR/sast-result.json"
VULN_RESULT="$REPORT_DIR/vulnerability-result.json"
SSDLC_RESULT="$REPORT_DIR/ssdlc-result.json"

# Get summary values with defaults
SAST_TOTAL=0
SAST_CRITICAL=0
SAST_HIGH=0

VULN_TOTAL=0
VULN_CRITICAL=0
VULN_HIGH=0

SSDLC_PASS=0
SSDLC_FAIL=0
SSDLC_WARN=0
SSDLC_TOTAL=0

if [ -f "$SAST_RESULT" ]; then
  SAST_TOTAL=$(jq '.summary.total_findings // 0' "$SAST_RESULT" 2>/dev/null || echo "0")
  SAST_CRITICAL=$(jq '.summary.critical // 0' "$SAST_RESULT" 2>/dev/null || echo "0")
  SAST_HIGH=$(jq '.summary.high // 0' "$SAST_RESULT" 2>/dev/null || echo "0")
fi

if [ -f "$VULN_RESULT" ]; then
  VULN_TOTAL=$(jq '.summary.total // 0' "$VULN_RESULT" 2>/dev/null || echo "0")
  VULN_CRITICAL=$(jq '.summary.critical // 0' "$VULN_RESULT" 2>/dev/null || echo "0")
  VULN_HIGH=$(jq '.summary.high // 0' "$VULN_RESULT" 2>/dev/null || echo "0")
fi

if [ -f "$SSDLC_RESULT" ]; then
  SSDLC_PASS=$(jq '.summary.pass // 0' "$SSDLC_RESULT" 2>/dev/null || echo "0")
  SSDLC_FAIL=$(jq '.summary.fail // 0' "$SSDLC_RESULT" 2>/dev/null || echo "0")
  SSDLC_WARN=$(jq '.summary.warn // 0' "$SSDLC_RESULT" 2>/dev/null || echo "0")
  SSDLC_TOTAL=$(jq '.summary.total // 0' "$SSDLC_RESULT" 2>/dev/null || echo "0")
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Generate SSDLC table rows
SSDLC_ROWS=""
if [ -f "$SSDLC_RESULT" ]; then
  SSDLC_ROWS=$(jq -r '.checks[] | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.name)</td><td class=\"px-4 py-2 status-\(.status | ascii_downcase)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.detail)</td></tr>"' "$SSDLC_RESULT" 2>/dev/null || echo "")
fi

# Generate SAST findings
SAST_CONTENT=""
if [ -f "$REPORT_DIR/semgrep-report.json" ]; then
  SAST_CONTENT=$(jq -r '.results[:20][] | "[\(.extra.severity // "INFO")] \(.path):\(.start.line)\n  \(.extra.message // "No message")\n"' "$REPORT_DIR/semgrep-report.json" 2>/dev/null || echo "No findings")
fi

# Generate vulnerability content
VULN_CONTENT=""
if [ -f "$REPORT_DIR/trivy-report.txt" ]; then
  VULN_CONTENT=$(head -100 "$REPORT_DIR/trivy-report.txt" 2>/dev/null || echo "No report")
fi

# Generate HTML report
cat > "$REPORT_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$PROJECT_NAME - 安全掃描報告</title>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
  <style>
    .status-pass { color: #10b981; }
    .status-fail { color: #ef4444; }
    .status-warn { color: #f59e0b; }
    pre { background: #1e1e1e; border-radius: 8px; padding: 1rem; overflow-x: auto; font-size: 0.875rem; }
  </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-6xl">
    <!-- Header -->
    <header class="mb-8">
      <h1 class="text-3xl font-bold mb-2">$PROJECT_NAME</h1>
      <p class="text-gray-400">
        <a href="$REPO_URL" class="text-blue-400 hover:underline" target="_blank">$REPO_URL</a>
      </p>
      <p class="text-gray-500 text-sm mt-1">掃描時間: $TIMESTAMP</p>
    </header>

    <!-- Summary Cards -->
    <div class="grid grid-cols-4 gap-4 mb-8">
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-green-400">$SSDLC_PASS/$SSDLC_TOTAL</p>
        <p class="text-gray-400 text-sm">SSDLC 通過</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-yellow-400">$SAST_TOTAL</p>
        <p class="text-gray-400 text-sm">SAST 發現</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-red-400">$VULN_CRITICAL</p>
        <p class="text-gray-400 text-sm">Critical 漏洞</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-orange-400">$VULN_HIGH</p>
        <p class="text-gray-400 text-sm">High 漏洞</p>
      </div>
    </div>

    <!-- SSDLC Section -->
    <section id="ssdlc" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">SSDLC 安全開發生命週期檢核</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700">
            <tr>
              <th class="px-4 py-3 text-left">檢核項目</th>
              <th class="px-4 py-3 text-left">狀態</th>
              <th class="px-4 py-3 text-left">說明</th>
            </tr>
          </thead>
          <tbody>
$SSDLC_ROWS
          </tbody>
        </table>
      </div>
    </section>

    <!-- SAST Section -->
    <section id="sast" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">SAST 源碼掃描 (Semgrep)</h2>
      <div class="bg-gray-800 p-4 rounded-lg">
        <p class="mb-2">發現 <span class="text-yellow-400 font-bold">$SAST_TOTAL</span> 個問題</p>
        <pre><code>$SAST_CONTENT</code></pre>
      </div>
    </section>

    <!-- Vulnerability Section -->
    <section id="vulnerability" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">弱點掃描 (Trivy)</h2>
      <div class="bg-gray-800 p-4 rounded-lg">
        <p class="mb-2">
          Critical: <span class="text-red-400 font-bold">$VULN_CRITICAL</span> |
          High: <span class="text-orange-400 font-bold">$VULN_HIGH</span> |
          Total: <span class="text-yellow-400 font-bold">$VULN_TOTAL</span>
        </p>
        <pre><code>$VULN_CONTENT</code></pre>
      </div>
    </section>

    <!-- Back Link -->
    <div class="mt-8">
      <a href="../" class="text-blue-400 hover:underline">&larr; 返回報告列表</a>
    </div>
  </div>
</body>
</html>
EOF

# Save summary for index generation
cat > "$REPORT_DIR/summary.json" << EOF
{
  "project_name": "$PROJECT_NAME",
  "repo_url": "$REPO_URL",
  "timestamp": "$TIMESTAMP",
  "ssdlc": {
    "pass": $SSDLC_PASS,
    "total": $SSDLC_TOTAL
  },
  "sast": {
    "total": $SAST_TOTAL
  },
  "vulnerability": {
    "critical": $VULN_CRITICAL,
    "high": $VULN_HIGH,
    "total": $VULN_TOTAL
  }
}
EOF

echo "  Project report generated: $REPORT_DIR/index.html"
