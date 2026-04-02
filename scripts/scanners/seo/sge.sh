#!/bin/bash
# SGE/AEO Marker Checker - Check for AI search optimization markers

HTML_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$HTML_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: sge.sh <html_file> <output_directory>"
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

# Count H2 headings
H2_COUNT=$(grep -c '<h2' "$HTML_FILE" 2>/dev/null || echo "0")
H2_COUNT=$(safe_int "$H2_COUNT")

# 1. Check .key-answer
KEY_ANSWER_COUNT=$(grep -c 'class="[^"]*key-answer' "$HTML_FILE" 2>/dev/null || echo "0")
KEY_ANSWER_COUNT=$(safe_int "$KEY_ANSWER_COUNT")
if [ "$KEY_ANSWER_COUNT" -ge "$H2_COUNT" ] && [ "$H2_COUNT" -gt 0 ]; then
  add_check ".key-answer" "pass" "$KEY_ANSWER_COUNT 個 (H2: $H2_COUNT)"
else
  add_check ".key-answer" "fail" "需要每個 H2 都有 .key-answer ($KEY_ANSWER_COUNT/$H2_COUNT)"
fi

# 2. Check .key-answer has data-question
KEY_ANSWER_DATA_Q=$(grep -c 'class="[^"]*key-answer[^"]*"[^>]*data-question' "$HTML_FILE" 2>/dev/null || echo "0")
KEY_ANSWER_DATA_Q=$(safe_int "$KEY_ANSWER_DATA_Q")
if [ "$KEY_ANSWER_DATA_Q" -ge "$KEY_ANSWER_COUNT" ] && [ "$KEY_ANSWER_COUNT" -gt 0 ]; then
  add_check ".key-answer[data-question]" "pass" "所有 .key-answer 都有 data-question"
else
  add_check ".key-answer[data-question]" "fail" "需要 data-question 屬性 ($KEY_ANSWER_DATA_Q/$KEY_ANSWER_COUNT)"
fi

# 3. Check .key-takeaway
KEY_TAKEAWAY_COUNT=$(grep -c 'class="[^"]*key-takeaway' "$HTML_FILE" 2>/dev/null || echo "0")
KEY_TAKEAWAY_COUNT=$(safe_int "$KEY_TAKEAWAY_COUNT")
if [ "$KEY_TAKEAWAY_COUNT" -ge 2 ]; then
  add_check ".key-takeaway" "pass" "$KEY_TAKEAWAY_COUNT 個重點摘要"
else
  add_check ".key-takeaway" "fail" "需要 2-3 個 .key-takeaway ($KEY_TAKEAWAY_COUNT)"
fi

# 4. Check .expert-quote
EXPERT_QUOTE_COUNT=$(grep -c 'class="[^"]*expert-quote' "$HTML_FILE" 2>/dev/null || echo "0")
EXPERT_QUOTE_COUNT=$(safe_int "$EXPERT_QUOTE_COUNT")
if [ "$EXPERT_QUOTE_COUNT" -ge 1 ]; then
  add_check ".expert-quote" "pass" "$EXPERT_QUOTE_COUNT 個專家引言"
else
  add_check ".expert-quote" "fail" "需要至少 1 個 .expert-quote"
fi

# 5. Check .actionable-steps
ACTIONABLE_STEPS_COUNT=$(grep -c 'class="[^"]*actionable-steps' "$HTML_FILE" 2>/dev/null || echo "0")
ACTIONABLE_STEPS_COUNT=$(safe_int "$ACTIONABLE_STEPS_COUNT")
if [ "$ACTIONABLE_STEPS_COUNT" -ge 1 ]; then
  add_check ".actionable-steps" "pass" "$ACTIONABLE_STEPS_COUNT 個行動步驟區塊"
else
  add_check ".actionable-steps" "fail" "需要 .actionable-steps 行動步驟"
fi

# 6. Check .comparison-table (only if there's a table)
TABLE_COUNT=$(grep -c '<table' "$HTML_FILE" 2>/dev/null || echo "0")
TABLE_COUNT=$(safe_int "$TABLE_COUNT")
if [ "$TABLE_COUNT" -gt 0 ]; then
  COMPARISON_TABLE_COUNT=$(grep -c 'class="[^"]*comparison-table' "$HTML_FILE" 2>/dev/null || echo "0")
  COMPARISON_TABLE_COUNT=$(safe_int "$COMPARISON_TABLE_COUNT")
  if [ "$COMPARISON_TABLE_COUNT" -ge 1 ]; then
    add_check ".comparison-table" "pass" "$COMPARISON_TABLE_COUNT 個比較表格"
  else
    add_check ".comparison-table" "fail" "有表格但缺少 .comparison-table 標記"
  fi
fi

# Build JSON output
TOTAL=$((PASS_COUNT + FAIL_COUNT))
CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")

cat > "$OUTPUT_DIR/sge-result.json" << EOF
{
  "status": "completed",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "pass": $PASS_COUNT,
    "fail": $FAIL_COUNT,
    "total": $TOTAL
  },
  "h2_count": $H2_COUNT,
  "checks": [$CHECKS_JSON]
}
EOF
