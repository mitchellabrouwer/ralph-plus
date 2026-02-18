#!/bin/bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(pwd)"

if [ "$TARGET" = "$RALPH_DIR" ]; then
  echo "Run this from your target project, not from ralph-plus itself."
  echo "  cd /path/to/my-project && path/to/ralph-plus/setup.sh"
  exit 1
fi

UPDATE=false
[ -d "$TARGET/ralph-plus" ] && UPDATE=true

mkdir -p "$TARGET/.claude/agents" "$TARGET/ralph-plus" "$TARGET/docs/tasks"

cp "$RALPH_DIR"/agents/*.md "$TARGET/.claude/agents/"
cp "$RALPH_DIR"/ralph-plus/run-monitored.sh "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/run-unmonitored.sh "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/dashboard.sh "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/check-complexity.sh "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/check-security.sh "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/CLAUDE.md "$TARGET/ralph-plus/"
cp "$RALPH_DIR"/ralph-plus/HOW-TO.md "$TARGET/ralph-plus/"

# Only copy MCP config if one doesn't already exist
if [ ! -f "$TARGET/.mcp.json" ]; then
  cp "$RALPH_DIR/.mcp.json" "$TARGET/"
  echo "Copied .mcp.json (edit to match your setup)"
else
  echo "Skipped .mcp.json (already exists)"
fi

if [ "$UPDATE" = true ]; then
  echo "Updated ralph-plus to latest."
else
  echo "Done. Next steps:"
  echo "  1. claude 'Use the architect agent to initialize this project'"
  echo "  2. claude 'Use the strategist agent to plan [your feature]'"
  echo "  3. ./ralph-plus/run-monitored.sh --task task-<name>.json"
fi
