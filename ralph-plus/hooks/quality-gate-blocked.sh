#!/bin/bash
#
# Hook: SubagentStop -> quality-gate
# Fires a macOS notification when the quality gate reports BLOCKED status.
#
# To activate, add to your project's .claude/settings.json:
#
#   {
#     "hooks": {
#       "SubagentStop": [
#         {
#           "matcher": "quality-gate",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "ralph-plus/hooks/quality-gate-blocked.sh"
#             }
#           ]
#         }
#       ]
#     }
#   }
#

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

if grep -q 'BLOCKED' "$TRANSCRIPT" 2>/dev/null; then
  osascript -e 'display notification "Environment/tooling issue detected. Pipeline halted - check terminal." with title "Quality Gate BLOCKED" sound name "Funk"'
fi

exit 0
