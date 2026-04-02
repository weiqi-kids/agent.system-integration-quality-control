#!/bin/bash
# Core Web Vitals Indicator Checker

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: cwv.sh <html_file> <output_directory>"
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

# Count images
TOTAL_IMAGES=$(grep -c '<img' "$HTML_FILE" 2>/dev/null || echo "0")
TOTAL_IMAGES=$(safe_int "$TOTAL_IMAGES")

# 1. Check for lazy loading on images
LAZY_IMAGES=$(grep -c 'loading="lazy"' "$HTML_FILE" 2>/dev/null || echo "0")
EAGER_IMAGES=$(grep -c 'loading="eager"' "$HTML_FILE" 2>/dev/null || echo "0")
LAZY_IMAGES=$(safe_int "$LAZY_IMAGES")
EAGER_IMAGES=$(safe_int "$EAGER_IMAGES")

if [ "$TOTAL_IMAGES" -gt 0 ]; then
  # First image should be eager, rest should be lazy
  FIRST_IMG=$(grep -m1 '<img' "$HTML_FILE")
  if echo "$FIRST_IMG" | grep -q 'loading="eager"'; then
    add_check "首屏圖片 loading" "pass" "使用 eager"
  else
    add_check "首屏圖片 loading" "fail" "首屏圖片應使用 loading=\"eager\""
  fi

  # Rest should be lazy
  if [ "$LAZY_IMAGES" -gt 0 ]; then
    add_check "延遲載入圖片" "pass" "$LAZY_IMAGES 張使用 lazy"
  else
    add_check "延遲載入圖片" "fail" "非首屏圖片應使用 loading=\"lazy\""
  fi
else
  add_check "圖片載入設定" "pass" "無圖片"
fi

# 2. Check for image dimensions (width/height)
IMAGES_WITH_DIMS=$(grep -cE '<img[^>]+(width|height)=' "$HTML_FILE" 2>/dev/null || echo "0")
IMAGES_WITH_DIMS=$(safe_int "$IMAGES_WITH_DIMS")
if [ "$TOTAL_IMAGES" -gt 0 ]; then
  if [ "$IMAGES_WITH_DIMS" -eq "$TOTAL_IMAGES" ]; then
    add_check "圖片尺寸宣告" "pass" "所有圖片都有 width/height"
  else
    add_check "圖片尺寸宣告" "fail" "$IMAGES_WITH_DIMS/$TOTAL_IMAGES 張圖片有尺寸宣告 (防止 CLS)"
  fi
else
  add_check "圖片尺寸宣告" "pass" "無圖片"
fi

# 3. Check for preconnect hints
PRECONNECT_COUNT=$(grep -c 'rel="preconnect"' "$HTML_FILE" 2>/dev/null || echo "0")
PRECONNECT_COUNT=$(safe_int "$PRECONNECT_COUNT")
if [ "$PRECONNECT_COUNT" -ge 1 ]; then
  add_check "preconnect 提示" "pass" "$PRECONNECT_COUNT 個預連線"
else
  add_check "preconnect 提示" "fail" "建議新增 preconnect 給第三方資源"
fi

# 4. Check for preload hints
PRELOAD_COUNT=$(grep -c 'rel="preload"' "$HTML_FILE" 2>/dev/null || echo "0")
PRELOAD_COUNT=$(safe_int "$PRELOAD_COUNT")
if [ "$PRELOAD_COUNT" -ge 1 ]; then
  add_check "preload 提示" "pass" "$PRELOAD_COUNT 個關鍵資源預載"
else
  add_check "preload 提示" "fail" "建議預載關鍵 CSS/字體"
fi

# 5. Check URL structure (from og:url or canonical)
PAGE_URL=$(sed -n 's/.*property="og:url"[^>]*content="\([^"]*\)".*/\1/p' "$HTML_FILE" | head -1)
if [ -z "$PAGE_URL" ]; then
  PAGE_URL=$(sed -n 's/.*content="\([^"]*\)"[^>]*property="og:url".*/\1/p' "$HTML_FILE" | head -1)
fi
if [ -z "$PAGE_URL" ]; then
  PAGE_URL=$(sed -n 's/.*rel="canonical"[^>]*href="\([^"]*\)".*/\1/p' "$HTML_FILE" | head -1)
fi
if [ -z "$PAGE_URL" ]; then
  PAGE_URL=$(sed -n 's/.*href="\([^"]*\)"[^>]*rel="canonical".*/\1/p' "$HTML_FILE" | head -1)
fi

if [ -n "$PAGE_URL" ]; then
  URL_PATH=$(echo "$PAGE_URL" | sed -E 's|https?://[^/]+||')

  # Check lowercase
  if echo "$URL_PATH" | grep -qE '[A-Z]'; then
    add_check "URL 小寫" "fail" "URL 應全部小寫"
  else
    add_check "URL 小寫" "pass" "全部小寫"
  fi

  # Check hyphen usage (no underscores)
  if echo "$URL_PATH" | grep -q '_'; then
    add_check "URL 連字號" "fail" "應使用連字號(-)而非底線(_)"
  else
    add_check "URL 連字號" "pass" "使用連字號"
  fi
else
  add_check "URL 結構" "fail" "無法取得 URL (缺少 og:url 或 canonical)"
fi

# 6. Check for async/defer on scripts
TOTAL_SCRIPTS=$(grep -c '<script' "$HTML_FILE" 2>/dev/null || echo "0")
ASYNC_DEFER_SCRIPTS=$(grep -cE '<script[^>]+(async|defer)' "$HTML_FILE" 2>/dev/null || echo "0")
TOTAL_SCRIPTS=$(safe_int "$TOTAL_SCRIPTS")
ASYNC_DEFER_SCRIPTS=$(safe_int "$ASYNC_DEFER_SCRIPTS")

if [ "$TOTAL_SCRIPTS" -gt 0 ]; then
  if [ "$ASYNC_DEFER_SCRIPTS" -gt 0 ]; then
    add_check "非阻塞腳本" "pass" "$ASYNC_DEFER_SCRIPTS 個腳本使用 async/defer"
  else
    add_check "非阻塞腳本" "fail" "建議腳本使用 async 或 defer"
  fi
fi

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/cwv-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "total": $TOTAL
  },
  "images": {
    "total": $TOTAL_IMAGES,
    "lazy": $LAZY_IMAGES,
    "eager": $EAGER_IMAGES,
    "with_dimensions": $IMAGES_WITH_DIMS
  },
  "checks": [$CHECKS_JSON]
}
EOF
