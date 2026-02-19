#!/bin/bash
# Ralph+ Monitored Mode - runs pipeline in tmux session
#
# Usage:
#   ./run-monitored.sh --task task-foo.json [--provider claude|codex] [max_iterations]
#
# Attach to watch:   tmux attach -t ralph-<slug>
# Detach:            Ctrl-b d

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$SCRIPT_DIR/../docs/tasks"

# Pass all args through, but also extract --task to derive session name
TASK_NAME=""
for arg in "$@"; do
  case $prev in
    --task) TASK_NAME="$arg" ;;
  esac
  if [[ "$arg" == --task=* ]]; then
    TASK_NAME="${arg#*=}"
  fi
  prev="$arg"
done

# Derive slug for tmux session name
if [ -n "$TASK_NAME" ]; then
  TASK_SLUG="${TASK_NAME#task-}"
  TASK_SLUG="${TASK_SLUG%.json}"
else
  shopt -s nullglob
  TASK_MATCHES=("$TASK_DIR"/task-*.json)
  shopt -u nullglob
  if [ "${#TASK_MATCHES[@]}" -eq 1 ]; then
    TASK_SLUG=$(basename "${TASK_MATCHES[0]}")
    TASK_SLUG="${TASK_SLUG#task-}"
    TASK_SLUG="${TASK_SLUG%.json}"
  else
    echo "Error: --task required when multiple task files exist"
    exit 1
  fi
fi

SESSION_NAME="ralph-$TASK_SLUG"
OUTPUT_LOG="$TASK_DIR/output-$TASK_SLUG.log"

# Kill existing session for this task if any
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Killing existing session: $SESSION_NAME"
  tmux kill-session -t "$SESSION_NAME"
fi

# Start pipeline in detached tmux session
CMD="cd '$SCRIPT_DIR' && ./run-unmonitored.sh $*"
tmux new-session -d -s "$SESSION_NAME" "$CMD"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Error: Failed to create tmux session"
  exit 1
fi

# Capture all output to log file
tmux pipe-pane -t "$SESSION_NAME" -o "cat >> '$OUTPUT_LOG'"

echo "========================================"
echo "Ralph+ Monitored Mode"
echo "Session: $SESSION_NAME"
echo "Output:  $OUTPUT_LOG"
echo ""
echo "Attaching to session..."
echo "Detach with: Ctrl-b d"
echo "Reattach:    tmux attach -t $SESSION_NAME"
echo "========================================"

# Attach immediately
tmux attach -t "$SESSION_NAME"
