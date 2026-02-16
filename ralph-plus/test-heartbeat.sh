#!/bin/bash
# test-heartbeat.sh - PoC test validating that claude can prepend heartbeat lines to an activity log
# Usage: ./ralph-plus/test-heartbeat.sh
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

if ! command -v claude &> /dev/null; then
  echo -e "${RED}FAIL: claude CLI not found on PATH${NC}"
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
ACTIVITY_LOG="$WORK_DIR/activity-test.log"

# Seed the log with an initial line to verify prepend ordering
echo "[2026-01-01 00:00:00] [0/0] US-000 seed: initial line" > "$ACTIVITY_LOG"

PROMPT="You have access to the Bash tool. Run exactly 3 bash commands, one at a time. Each command prepends a heartbeat line to the file at ${ACTIVITY_LOG}.

Use this exact pattern for each command (change only the message):
tmp=\$(mktemp) && { echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [1/10] US-003 test-heartbeat: MESSAGE\"; cat ${ACTIVITY_LOG}; } > \"\$tmp\" && mv \"\$tmp\" ${ACTIVITY_LOG}

Messages to use (one per command, in this order):
1. heartbeat 1 of 3
2. heartbeat 2 of 3
3. heartbeat 3 of 3

Run each command separately. Do not combine them."

echo -e "${DIM}Running claude --print with Bash tool...${NC}"
claude --print --allowedTools Bash --dangerously-skip-permissions --model haiku "$PROMPT" > /dev/null 2>&1 || true

# Verify the activity log file still exists
if [ ! -f "$ACTIVITY_LOG" ]; then
  echo -e "${RED}FAIL: Activity log file does not exist after claude session${NC}"
  exit 1
fi

HEARTBEAT_COUNT=$(grep -c '\[1/10\] US-003 test-heartbeat:' "$ACTIVITY_LOG" || true)
SEED_PRESENT=$(grep -c 'US-000 seed: initial line' "$ACTIVITY_LOG" || true)
TOTAL_LINES=$(wc -l < "$ACTIVITY_LOG" | tr -d ' ')

# Check at least 3 heartbeat lines were prepended
if [ "$HEARTBEAT_COUNT" -lt 3 ]; then
  echo -e "${RED}FAIL: Expected at least 3 heartbeat lines, found ${HEARTBEAT_COUNT}${NC}"
  echo -e "${DIM}Activity log contents:${NC}"
  cat "$ACTIVITY_LOG"
  exit 1
fi

# Check the seed line was not lost during prepend operations
if [ "$SEED_PRESENT" -lt 1 ]; then
  echo -e "${RED}FAIL: Seed line was lost during prepend operations${NC}"
  echo -e "${DIM}Activity log contents:${NC}"
  cat "$ACTIVITY_LOG"
  exit 1
fi

# Check seed line is last (proving prepend ordering)
LAST_LINE=$(tail -1 "$ACTIVITY_LOG")
if ! echo "$LAST_LINE" | grep -q 'US-000 seed: initial line'; then
  echo -e "${RED}FAIL: Seed line is not the last line - prepend ordering broken${NC}"
  echo -e "${DIM}Activity log contents:${NC}"
  cat "$ACTIVITY_LOG"
  exit 1
fi

echo -e "${GREEN}${BOLD}PASS${NC}: Heartbeat PoC - ${HEARTBEAT_COUNT} heartbeat lines found, prepend order correct, seed line preserved (${TOTAL_LINES} total lines)"
