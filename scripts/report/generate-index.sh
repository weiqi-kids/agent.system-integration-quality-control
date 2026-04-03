#!/bin/bash
# Generate index page for all scan results

SCAN_DIR="$1"

if [ -z "$SCAN_DIR" ]; then
  echo "Usage: generate-index.sh <scan_directory>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCS_DIR="$PROJECT_ROOT/docs"

SCAN_ID=$(basename "$SCAN_DIR")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Read metadata
WEB_URL=""
CUR_PROJECT_NAME=""
if [ -f "$SCAN_DIR/metadata.json" ]; then
  WEB_URL=$(jq -r '.web_url // ""' "$SCAN_DIR/metadata.json" 2>/dev/null || echo "")
  CUR_PROJECT_NAME=$(jq -r '.project_name // ""' "$SCAN_DIR/metadata.json" 2>/dev/null || echo "")
fi
if [ -z "$CUR_PROJECT_NAME" ]; then CUR_PROJECT_NAME="unknown"; fi

# Get pentest results
PENTEST_TOTAL=0
PENTEST_DIR="$SCAN_DIR/pentest"
if [ -f "$PENTEST_DIR/pentest-result.json" ]; then
  PENTEST_TOTAL=$(jq '.summary.total_findings // 0' "$PENTEST_DIR/pentest-result.json" 2>/dev/null || echo "0")
fi

# Get SEO results
SEO_DIR="$SCAN_DIR/seo"
LINKS_OK=0
LINKS_BROKEN=0
META_PASS=0
META_TOTAL=0
SCHEMA_PASS=0
SCHEMA_TOTAL=0
SGE_PASS=0
SGE_TOTAL=0

if [ -f "$SEO_DIR/links-result.json" ]; then
  LINKS_OK=$(jq '.summary.ok // 0' "$SEO_DIR/links-result.json" 2>/dev/null || echo "0")
  LINKS_BROKEN=$(jq '.summary.broken // 0' "$SEO_DIR/links-result.json" 2>/dev/null || echo "0")
fi

if [ -f "$SEO_DIR/seo-result.json" ]; then
  META_PASS=$(jq '.categories.meta.pass // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  META_TOTAL=$(jq '.categories.meta.total // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  SCHEMA_PASS=$(jq '.categories.schema.pass // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  SCHEMA_TOTAL=$(jq '.categories.schema.total // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  SGE_PASS=$(jq '.categories.sge.pass // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  SGE_TOTAL=$(jq '.categories.sge.total // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
fi

# Generate scan index page (for this specific scan)
echo "Generating scan index page..."

# Collect project rows
PROJECT_ROWS=""

for project_dir in "$SCAN_DIR"/*/; do
  if [ -d "$project_dir" ] && [ "$(basename "$project_dir")" != "pentest" ] && [ "$(basename "$project_dir")" != "seo" ]; then
    project_name=$(basename "$project_dir")
    summary_file="$project_dir/summary.json"

    if [ -f "$summary_file" ]; then
      REPO_URL=$(jq -r '.repo_url // ""' "$summary_file" 2>/dev/null || echo "")
      SSDLC_PASS=$(jq '.ssdlc.pass // 0' "$summary_file" 2>/dev/null || echo "0")
      SSDLC_TOTAL=$(jq '.ssdlc.total // 0' "$summary_file" 2>/dev/null || echo "0")
      SAST_TOTAL=$(jq '.sast.total // 0' "$summary_file" 2>/dev/null || echo "0")
      VULN_CRITICAL=$(jq '.vulnerability.critical // 0' "$summary_file" 2>/dev/null || echo "0")
      VULN_HIGH=$(jq '.vulnerability.high // 0' "$summary_file" 2>/dev/null || echo "0")

      # Build links
      LINKS="<a href=\"$REPO_URL\" class=\"text-blue-400 hover:underline\" target=\"_blank\">repo</a>"
      if [ -n "$WEB_URL" ]; then
        LINKS="$LINKS / <a href=\"$WEB_URL\" class=\"text-blue-400 hover:underline\" target=\"_blank\">web</a>"
      fi

      PROJECT_ROWS="$PROJECT_ROWS
      <tr class=\"border-t border-gray-700 hover:bg-gray-750\">
        <td class=\"px-3 py-3 font-medium\">$project_name</td>
        <td class=\"px-3 py-3\">$LINKS</td>
        <td class=\"px-3 py-3 font-mono text-sm\">$TIMESTAMP</td>
        <td class=\"px-3 py-3\"><a href=\"$project_name/#ssdlc\" class=\"hover:underline\">$SSDLC_PASS/$SSDLC_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"$project_name/#sast\" class=\"hover:underline text-yellow-400\">$SAST_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"$project_name/#vulnerability\" class=\"hover:underline\"><span class=\"text-red-400\">$VULN_CRITICAL</span>/<span class=\"text-orange-400\">$VULN_HIGH</span></a></td>
        <td class=\"px-3 py-3\"><a href=\"pentest/\" class=\"hover:underline text-purple-400\">$PENTEST_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/\" class=\"hover:underline text-green-400\">$LINKS_OK/$((LINKS_OK + LINKS_BROKEN))</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#meta\" class=\"hover:underline text-cyan-400\">$META_PASS/$META_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#schema\" class=\"hover:underline text-pink-400\">$SCHEMA_PASS/$SCHEMA_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#sge\" class=\"hover:underline text-indigo-400\">$SGE_PASS/$SGE_TOTAL</a></td>
      </tr>"
    fi
  fi
done

# Web-only scan: add a row when no repo projects exist
if [ -z "$PROJECT_ROWS" ] && [ -n "$WEB_URL" ]; then
  PROJECT_ROWS="
      <tr class=\"border-t border-gray-700 hover:bg-gray-750\">
        <td class=\"px-3 py-3 font-medium\">$CUR_PROJECT_NAME</td>
        <td class=\"px-3 py-3\"><a href=\"$WEB_URL\" class=\"text-blue-400 hover:underline\" target=\"_blank\">$WEB_URL</a></td>
        <td class=\"px-3 py-3 font-mono text-sm\">$TIMESTAMP</td>
        <td class=\"px-3 py-3 text-gray-500\">-</td>
        <td class=\"px-3 py-3 text-gray-500\">-</td>
        <td class=\"px-3 py-3 text-gray-500\">-</td>
        <td class=\"px-3 py-3\"><a href=\"pentest/\" class=\"hover:underline text-purple-400\">$PENTEST_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/\" class=\"hover:underline text-green-400\">$LINKS_OK/$((LINKS_OK + LINKS_BROKEN))</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#meta\" class=\"hover:underline text-cyan-400\">$META_PASS/$META_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#schema\" class=\"hover:underline text-pink-400\">$SCHEMA_PASS/$SCHEMA_TOTAL</a></td>
        <td class=\"px-3 py-3\"><a href=\"seo/#sge\" class=\"hover:underline text-indigo-400\">$SGE_PASS/$SGE_TOTAL</a></td>
      </tr>"
fi

# Generate scan index HTML
cat > "$SCAN_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>安全掃描報告 - $SCAN_ID</title>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
  <style>
    .hover\:bg-gray-750:hover { background-color: #374151; }
  </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-7xl">
    <header class="mb-8">
      <h1 class="text-3xl font-bold mb-2">安全掃描報告</h1>
      <p class="text-gray-400">專案: <span class="font-mono">$CUR_PROJECT_NAME</span> (<a href="../../projects/$CUR_PROJECT_NAME/" class="text-blue-400 hover:underline">歷史紀錄</a>)</p>
      <p class="text-gray-400">Scan ID: <span class="font-mono">$SCAN_ID</span></p>
      <p class="text-gray-500 text-sm">掃描時間: $TIMESTAMP</p>
    </header>

    <div class="bg-gray-800 rounded-lg overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-700">
          <tr>
            <th class="px-3 py-3 text-left">專案</th>
            <th class="px-3 py-3 text-left">連結</th>
            <th class="px-3 py-3 text-left">時間</th>
            <th class="px-3 py-3 text-left">SSDLC</th>
            <th class="px-3 py-3 text-left">SAST</th>
            <th class="px-3 py-3 text-left">弱點</th>
            <th class="px-3 py-3 text-left">滲透</th>
            <th class="px-3 py-3 text-left">連結</th>
            <th class="px-3 py-3 text-left">Meta</th>
            <th class="px-3 py-3 text-left">Schema</th>
            <th class="px-3 py-3 text-left">SGE</th>
          </tr>
        </thead>
        <tbody>
$PROJECT_ROWS
        </tbody>
      </table>
    </div>

    <div class="mt-8">
      <a href="../../projects/$CUR_PROJECT_NAME/" class="text-blue-400 hover:underline">&larr; 返回專案歷史</a> | <a href="../../" class="text-blue-400 hover:underline">首頁</a>
    </div>
  </div>
</body>
</html>
EOF

# Generate pentest index if exists
if [ -d "$PENTEST_DIR" ] && [ -f "$PENTEST_DIR/pentest-result.json" ]; then
  PENTEST_CRITICAL=$(jq '.summary.critical // 0' "$PENTEST_DIR/pentest-result.json" 2>/dev/null || echo "0")
  PENTEST_HIGH=$(jq '.summary.high // 0' "$PENTEST_DIR/pentest-result.json" 2>/dev/null || echo "0")
  PENTEST_MEDIUM=$(jq '.summary.medium // 0' "$PENTEST_DIR/pentest-result.json" 2>/dev/null || echo "0")

  NUCLEI_CONTENT=""
  if [ -f "$PENTEST_DIR/nuclei-report.txt" ]; then
    NUCLEI_CONTENT=$(cat "$PENTEST_DIR/nuclei-report.txt" 2>/dev/null || echo "No findings")
  fi

  cat > "$PENTEST_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>滲透測試報告</title>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
  <style>
    pre { background: #1e1e1e; border-radius: 8px; padding: 1rem; overflow-x: auto; }
  </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-6xl">
    <header class="mb-8">
      <h1 class="text-3xl font-bold mb-2">滲透測試報告</h1>
      <p class="text-gray-400">目標: <a href="$WEB_URL" class="text-blue-400 hover:underline" target="_blank">$WEB_URL</a></p>
      <p class="text-gray-500 text-sm">掃描時間: $TIMESTAMP</p>
    </header>

    <div class="grid grid-cols-4 gap-4 mb-8">
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-purple-400">$PENTEST_TOTAL</p>
        <p class="text-gray-400 text-sm">總發現</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-red-400">$PENTEST_CRITICAL</p>
        <p class="text-gray-400 text-sm">Critical</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-orange-400">$PENTEST_HIGH</p>
        <p class="text-gray-400 text-sm">High</p>
      </div>
      <div class="bg-gray-800 p-4 rounded-lg text-center">
        <p class="text-2xl font-bold text-yellow-400">$PENTEST_MEDIUM</p>
        <p class="text-gray-400 text-sm">Medium</p>
      </div>
    </div>

    <section class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">Nuclei 掃描結果</h2>
      <div class="bg-gray-800 p-4 rounded-lg">
        <pre><code>$NUCLEI_CONTENT</code></pre>
      </div>
    </section>

    <div class="mt-8">
      <a href="../" class="text-blue-400 hover:underline">&larr; 返回報告列表</a>
    </div>
  </div>
</body>
</html>
EOF
fi

# Generate SEO report page
if [ -d "$SEO_DIR" ] && [ -f "$SEO_DIR/seo-result.json" ]; then
  echo "Generating SEO report page..."

  # Read all SEO results
  EEAT_PASS=$(jq '.categories.eeat.pass // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  EEAT_TOTAL=$(jq '.categories.eeat.total // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  CWV_PASS=$(jq '.categories.cwv.pass // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  CWV_TOTAL=$(jq '.categories.cwv.total // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")
  SEO_SCORE=$(jq '.summary.score // 0' "$SEO_DIR/seo-result.json" 2>/dev/null || echo "0")

  # Get check details
  META_CHECKS=$(jq -r '.checks[]? | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.item)</td><td class=\"px-4 py-2 \(if .status == "pass" then "text-green-400" else "text-red-400" end)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.value // .expected // "-")</td></tr>"' "$SEO_DIR/meta-result.json" 2>/dev/null || echo "")

  SCHEMA_CHECKS=$(jq -r '.checks[]? | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.item)</td><td class=\"px-4 py-2 \(if .status == "pass" then "text-green-400" else "text-red-400" end)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.detail // "-")</td></tr>"' "$SEO_DIR/schema-result.json" 2>/dev/null || echo "")

  SGE_CHECKS=$(jq -r '.checks[]? | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.item)</td><td class=\"px-4 py-2 \(if .status == "pass" then "text-green-400" else "text-red-400" end)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.detail // "-")</td></tr>"' "$SEO_DIR/sge-result.json" 2>/dev/null || echo "")

  EEAT_CHECKS=$(jq -r '.checks[]? | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.item)</td><td class=\"px-4 py-2 \(if .status == "pass" then "text-green-400" else "text-red-400" end)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.detail // "-")</td></tr>"' "$SEO_DIR/eeat-result.json" 2>/dev/null || echo "")

  CWV_CHECKS=$(jq -r '.checks[]? | "<tr class=\"border-t border-gray-700\"><td class=\"px-4 py-2\">\(.item)</td><td class=\"px-4 py-2 \(if .status == "pass" then "text-green-400" else "text-red-400" end)\">\(.status)</td><td class=\"px-4 py-2 text-gray-400\">\(.detail // "-")</td></tr>"' "$SEO_DIR/cwv-result.json" 2>/dev/null || echo "")

  cat > "$SEO_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SEO/AEO 檢查報告</title>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-6xl">
    <header class="mb-8">
      <h1 class="text-3xl font-bold mb-2">SEO/AEO 檢查報告</h1>
      <p class="text-gray-400">目標: <a href="$WEB_URL" class="text-blue-400 hover:underline" target="_blank">$WEB_URL</a></p>
      <p class="text-gray-500 text-sm">掃描時間: $TIMESTAMP</p>
    </header>

    <!-- Summary Cards -->
    <div class="grid grid-cols-6 gap-3 mb-8">
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-blue-400">$SEO_SCORE%</p>
        <p class="text-gray-400 text-xs">總分</p>
      </div>
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-green-400">$LINKS_OK/$((LINKS_OK + LINKS_BROKEN))</p>
        <p class="text-gray-400 text-xs">連結</p>
      </div>
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-cyan-400">$META_PASS/$META_TOTAL</p>
        <p class="text-gray-400 text-xs">Meta</p>
      </div>
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-pink-400">$SCHEMA_PASS/$SCHEMA_TOTAL</p>
        <p class="text-gray-400 text-xs">Schema</p>
      </div>
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-indigo-400">$SGE_PASS/$SGE_TOTAL</p>
        <p class="text-gray-400 text-xs">SGE</p>
      </div>
      <div class="bg-gray-800 p-3 rounded-lg text-center">
        <p class="text-xl font-bold text-yellow-400">$EEAT_PASS/$EEAT_TOTAL</p>
        <p class="text-gray-400 text-xs">E-E-A-T</p>
      </div>
    </div>

    <!-- Meta Section -->
    <section id="meta" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">Meta 標籤檢查</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700"><tr><th class="px-4 py-2 text-left">項目</th><th class="px-4 py-2 text-left">狀態</th><th class="px-4 py-2 text-left">內容</th></tr></thead>
          <tbody>$META_CHECKS</tbody>
        </table>
      </div>
    </section>

    <!-- Schema Section -->
    <section id="schema" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">Schema 結構化資料</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700"><tr><th class="px-4 py-2 text-left">項目</th><th class="px-4 py-2 text-left">狀態</th><th class="px-4 py-2 text-left">說明</th></tr></thead>
          <tbody>$SCHEMA_CHECKS</tbody>
        </table>
      </div>
    </section>

    <!-- SGE Section -->
    <section id="sge" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">SGE/AEO 標記</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700"><tr><th class="px-4 py-2 text-left">項目</th><th class="px-4 py-2 text-left">狀態</th><th class="px-4 py-2 text-left">說明</th></tr></thead>
          <tbody>$SGE_CHECKS</tbody>
        </table>
      </div>
    </section>

    <!-- E-E-A-T Section -->
    <section id="eeat" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">E-E-A-T 信號</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700"><tr><th class="px-4 py-2 text-left">項目</th><th class="px-4 py-2 text-left">狀態</th><th class="px-4 py-2 text-left">說明</th></tr></thead>
          <tbody>$EEAT_CHECKS</tbody>
        </table>
      </div>
    </section>

    <!-- CWV Section -->
    <section id="cwv" class="mb-8">
      <h2 class="text-xl font-bold mb-4 border-b border-gray-700 pb-2">Core Web Vitals</h2>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-700"><tr><th class="px-4 py-2 text-left">項目</th><th class="px-4 py-2 text-left">狀態</th><th class="px-4 py-2 text-left">說明</th></tr></thead>
          <tbody>$CWV_CHECKS</tbody>
        </table>
      </div>
    </section>

    <div class="mt-8">
      <a href="../" class="text-blue-400 hover:underline">&larr; 返回報告列表</a>
    </div>
  </div>
</body>
</html>
EOF
fi

# ===========================================
#  Generate per-project history page
# ===========================================
echo "Updating project page..."

PROJ_DIR="$DOCS_DIR/projects/$CUR_PROJECT_NAME"
mkdir -p "$PROJ_DIR"

# Build scan rows for this project (newest first)
PROJ_SCAN_ROWS=""
PROJ_SCAN_COUNT=0

for scan_path in $(ls -dt "$DOCS_DIR/scans"/*/ 2>/dev/null); do
  [ ! -f "$scan_path/metadata.json" ] && continue
  spname=$(jq -r '.project_name // "unknown"' "$scan_path/metadata.json" 2>/dev/null || echo "unknown")
  if [ -z "$spname" ]; then spname="unknown"; fi
  [ "$spname" != "$CUR_PROJECT_NAME" ] && continue

  scan_name=$(basename "$scan_path")
  scan_date=$(echo "$scan_name" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
  PROJ_SCAN_COUNT=$((PROJ_SCAN_COUNT + 1))

  # Collect summary from first repo subdirectory
  SSDLC_S="-"; SAST_S="-"; VULN_S="-"
  for subdir in "$scan_path"/*/; do
    subname=$(basename "$subdir")
    [ "$subname" = "pentest" ] || [ "$subname" = "seo" ] && continue
    if [ -f "$subdir/summary.json" ]; then
      sp=$(jq '.ssdlc.pass // 0' "$subdir/summary.json" 2>/dev/null || echo 0)
      st=$(jq '.ssdlc.total // 0' "$subdir/summary.json" 2>/dev/null || echo 0)
      SSDLC_S="$sp/$st"
      SAST_S=$(jq '.sast.total // 0' "$subdir/summary.json" 2>/dev/null || echo 0)
      vc=$(jq '.vulnerability.critical // 0' "$subdir/summary.json" 2>/dev/null || echo 0)
      vh=$(jq '.vulnerability.high // 0' "$subdir/summary.json" 2>/dev/null || echo 0)
      VULN_S="${vc}C/${vh}H"
      break
    fi
  done

  PROJ_SCAN_ROWS="$PROJ_SCAN_ROWS
          <tr class=\"border-t border-gray-700 hover:bg-gray-750\">
            <td class=\"px-6 py-3 font-mono\"><a href=\"../../scans/$scan_name/\" class=\"text-blue-400 hover:underline\">$scan_name</a></td>
            <td class=\"px-6 py-3\">$scan_date</td>
            <td class=\"px-6 py-3\">$SSDLC_S</td>
            <td class=\"px-6 py-3\">$SAST_S</td>
            <td class=\"px-6 py-3\">$VULN_S</td>
          </tr>"
done

# Write project history page
cat > "$PROJ_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$CUR_PROJECT_NAME - 掃描歷史</title>
  <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
  <style>
    .hover\:bg-gray-750:hover { background-color: #374151; }
  </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-5xl">
    <header class="mb-8">
      <h1 class="text-3xl font-bold">$CUR_PROJECT_NAME</h1>
      <p class="text-gray-400 mt-2">掃描歷史紀錄 (共 $PROJ_SCAN_COUNT 次)</p>
    </header>

    <div class="bg-gray-800 rounded-lg overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-700">
          <tr>
            <th class="px-6 py-3 text-left">掃描 ID</th>
            <th class="px-6 py-3 text-left">時間</th>
            <th class="px-6 py-3 text-left">SSDLC</th>
            <th class="px-6 py-3 text-left">SAST</th>
            <th class="px-6 py-3 text-left">弱點</th>
          </tr>
        </thead>
        <tbody>
$PROJ_SCAN_ROWS
        </tbody>
      </table>
    </div>

    <div class="mt-8">
      <a href="../../" class="text-blue-400 hover:underline">&larr; 首頁</a>
    </div>

    <footer class="mt-8 text-center text-gray-500 text-sm">
      <p>Powered by System Integration Quality Control</p>
    </footer>
  </div>
</body>
</html>
EOF

echo "Project page generated: $PROJ_DIR/index.html"

# ===========================================
#  Generate docs/index.html (process flow, only if missing)
# ===========================================
if [ ! -f "$DOCS_DIR/index.html" ]; then
  echo "Generating landing page..."
  cp "$PROJECT_ROOT/templates/landing.html" "$DOCS_DIR/index.html"
fi

echo "Index pages generated successfully!"
