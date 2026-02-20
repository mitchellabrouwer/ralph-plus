#!/bin/bash
# Ralph+ Monitored Mode - interactive TUI in tmux session
#
# Runs the full pipeline iteration loop with the provider CLI in interactive
# mode (not --print / exec), injecting the prompt via tmux buffer paste so
# you get full visibility into what the agent and its sub-agents are doing.
#
# Usage:
#   ./run-monitored.sh --task task-foo.json [--provider claude|codex] [max_iterations]
#
# Attach to watch:   tmux attach -t <project>-<branch>
# Detach:            Ctrl-b d

set -e

# Ensure common binary paths are available inside tmux sessions
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
TASK_DIR="$SCRIPT_DIR/../docs/tasks"

# State files
CURRENT_TASK_FILE="$SCRIPT_DIR/.current-task"
CURRENT_PROGRESS_FILE="$SCRIPT_DIR/.current-progress"
CURRENT_ACTIVITY_FILE="$SCRIPT_DIR/.current-activity-log"
CURRENT_ITERATION_FILE="$SCRIPT_DIR/.current-iteration"

# Parse arguments
TASK_NAME=""
MAX_ITERATIONS=10
PROVIDER="claude"

while [[ $# -gt 0 ]]; do
  case $1 in
    --task) TASK_NAME="$2"; shift 2 ;;
    --task=*) TASK_NAME="${1#*=}"; shift ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --provider=*) PROVIDER="${1#*=}"; shift ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"; shift
      else
        echo "Error: Unknown argument '$1'"
        echo "Usage: ./run-monitored.sh --task task-<name>.json [--provider claude|codex] [max_iterations]"
        exit 1
      fi
      ;;
  esac
done

# Validate provider
case "$PROVIDER" in
  claude|codex) ;;
  *) echo "Error: Unknown provider '$PROVIDER'. Must be 'claude' or 'codex'."; exit 1 ;;
esac

# Resolve task file
if [ ! -d "$TASK_DIR" ]; then
  echo "Error: Tasks directory not found: $TASK_DIR"; exit 1
fi

if [ -z "$TASK_NAME" ]; then
  shopt -s nullglob
  TASK_MATCHES=("$TASK_DIR"/task-*.json)
  shopt -u nullglob
  if [ "${#TASK_MATCHES[@]}" -eq 0 ]; then
    echo "Error: No task files found in $TASK_DIR"; exit 1
  elif [ "${#TASK_MATCHES[@]}" -eq 1 ]; then
    TASK_FILE="${TASK_MATCHES[0]}"
  else
    echo "Error: --task is required when multiple task files exist."
    echo "Available tasks:"
    ls -1 "$TASK_DIR"/task-*.json 2>/dev/null | xargs -n 1 basename || true
    exit 1
  fi
else
  [[ "$TASK_NAME" != *.json ]] && TASK_NAME="task-$TASK_NAME.json"
  if [[ "$TASK_NAME" == */* ]]; then
    TASK_FILE="$TASK_NAME"
  else
    TASK_FILE="$TASK_DIR/$TASK_NAME"
  fi
fi

if [ ! -f "$TASK_FILE" ]; then
  echo "Error: Task file not found: $TASK_FILE"
  echo "Available tasks:"
  ls -1 "$TASK_DIR"/task-*.json 2>/dev/null | xargs -n 1 basename || true
  exit 1
fi

TASK_BASENAME=$(basename "$TASK_FILE")
TASK_SLUG="${TASK_BASENAME#task-}"
TASK_SLUG="${TASK_SLUG%.json}"
PROGRESS_FILE="$TASK_DIR/progress-$TASK_SLUG.txt"
ACTIVITY_LOG="$TASK_DIR/activity-$TASK_SLUG.log"
OUTPUT_LOG="$TASK_DIR/output-$TASK_SLUG.log"

# Session name: <project-root>-<branch>
PROJECT_ROOT=$(basename "$(cd "$SCRIPT_DIR/.." && pwd)")
GIT_BRANCH=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
SESSION_NAME="${PROJECT_ROOT}-${GIT_BRANCH}"
# tmux session names can't contain dots or colons
SESSION_NAME="${SESSION_NAME//[.:]/-}"

# Resolve provider binary before entering tmux (where PATH may differ)
PROVIDER_BIN=$(command -v "$PROVIDER" 2>/dev/null || true)
if [ -z "$PROVIDER_BIN" ]; then
  echo "Error: $PROVIDER CLI not found on PATH"; exit 1
fi

# ============================================================
# OUTER: create tmux session and attach
# ============================================================
if [ -z "${RALPH_MONITORED:-}" ]; then
  # Kill existing session for this task
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Killing existing session: $SESSION_NAME"
    tmux kill-session -t "$SESSION_NAME"
  fi

  # Launch this script inside a new tmux session
  tmux new-session -d -s "$SESSION_NAME" -c "$SCRIPT_DIR" \
    "env RALPH_MONITORED=1 RALPH_PROVIDER_BIN='$PROVIDER_BIN' bash '$SCRIPT_PATH' --task '$TASK_BASENAME' --provider '$PROVIDER' $MAX_ITERATIONS"

  if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Failed to create tmux session"; exit 1
  fi

  # Capture all output to log file
  tmux pipe-pane -t "$SESSION_NAME" -o "cat >> '$OUTPUT_LOG'"

  echo "========================================"
  echo "Ralph+ Monitored Mode"
  echo "Session:  $SESSION_NAME"
  echo "Output:   $OUTPUT_LOG"
  echo ""
  echo "Attaching to session..."
  echo "Detach with: Ctrl-b d"
  echo "Reattach:    tmux attach -t $SESSION_NAME"
  echo "========================================"

  tmux attach -t "$SESSION_NAME"
  exit 0
fi

# ============================================================
# INNER: running inside tmux - iteration loop
# ============================================================

# Use provider binary resolved by outer invocation
PROVIDER_BIN="${RALPH_PROVIDER_BIN:-$(command -v "$PROVIDER" 2>/dev/null)}"

# Write state files
echo "$TASK_FILE" > "$CURRENT_TASK_FILE"
echo "$PROGRESS_FILE" > "$CURRENT_PROGRESS_FILE"
echo "$ACTIVITY_LOG" > "$CURRENT_ACTIVITY_FILE"

prepend_log() {
  local tmp
  tmp=$(mktemp)
  if [ -f "$ACTIVITY_LOG" ]; then
    { echo "$1"; cat "$ACTIVITY_LOG"; } > "$tmp" && mv "$tmp" "$ACTIVITY_LOG"
  else
    echo "$1" > "$ACTIVITY_LOG"
  fi
}

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph+ Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "Task: $TASK_BASENAME" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Check optional dependencies
MISSING_OPTIONAL=()
command -v lizard &> /dev/null || MISSING_OPTIONAL+=("lizard (pip install lizard) - complexity checks")
command -v semgrep &> /dev/null || MISSING_OPTIONAL+=("semgrep (pip install semgrep) - security checks")

if [ ${#MISSING_OPTIONAL[@]} -gt 0 ]; then
  echo ""
  echo "Optional dependencies missing (quality gate will skip these checks):"
  for dep in "${MISSING_OPTIONAL[@]}"; do
    echo "  - $dep"
  done
  echo ""
fi

prepend_log "[$(date '+%Y-%m-%d %H:%M:%S')] pipeline: started task=$TASK_BASENAME max_iterations=$MAX_ITERATIONS provider=$PROVIDER mode=monitored"

echo "Starting Ralph+ (Monitored) - Task: $TASK_BASENAME - Provider: $PROVIDER - Max iterations: $MAX_ITERATIONS"

# Check if all stories pass in task file
all_stories_pass() {
  # If task file was archived (moved to completed/), task is done
  [ ! -f "$TASK_FILE" ] && return 0

  python3 -c "
import json, sys
with open('$TASK_FILE') as f:
  task = json.load(f)
stories = task.get('userStories', task.get('stories', []))
sys.exit(0 if stories and all(s.get('passes', False) for s in stories) else 1)
" 2>/dev/null
}

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Ralph+ Iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  echo "$i/$MAX_ITERATIONS" > "$CURRENT_ITERATION_FILE"
  prepend_log "[$(date '+%Y-%m-%d %H:%M:%S')] pipeline: iteration $i/$MAX_ITERATIONS started"

  # Interactive mode: inject prompt via tmux buffer paste
  PROMPT_FILE=$(mktemp)
  cat "$SCRIPT_DIR/CLAUDE.md" > "$PROMPT_FILE"
  BUFFER_NAME="ralph-prompt-$$-$i"

  # Background injector: waits for TUI to initialize, then pastes prompt
  (
    sleep 15
    tmux load-buffer -b "$BUFFER_NAME" "$PROMPT_FILE"
    sleep 1
    tmux paste-buffer -t "$SESSION_NAME" -b "$BUFFER_NAME"
    sleep 2
    tmux send-keys -t "$SESSION_NAME" Enter
    rm -f "$PROMPT_FILE"
    tmux delete-buffer -b "$BUFFER_NAME" 2>/dev/null || true
  ) &
  INJECTOR_PID=$!

  # Run provider interactively - full TUI visible in tmux
  if [ "$PROVIDER" = "claude" ]; then
    "$PROVIDER_BIN" --dangerously-skip-permissions || true
  else
    "$PROVIDER_BIN" --full-auto --no-alt-screen || true
  fi

  kill $INJECTOR_PID 2>/dev/null || true
  rm -f "$PROMPT_FILE" 2>/dev/null || true

  # Check completion by reading task file
  if all_stories_pass; then
    prepend_log "[$(date '+%Y-%m-%d %H:%M:%S')] pipeline: COMPLETE at iteration $i/$MAX_ITERATIONS"
    echo ""
    echo "Ralph+ completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  prepend_log "[$(date '+%Y-%m-%d %H:%M:%S')] pipeline: iteration $i/$MAX_ITERATIONS finished"
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph+ reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
