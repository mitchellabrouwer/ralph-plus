#!/bin/bash
# Ralph+ - Multi-agent pipeline for autonomous story implementation
# Usage: ./run-task-loop.sh --task task-<name>.json [max_iterations]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$SCRIPT_DIR/../docs/tasks"
CURRENT_TASK_FILE="$SCRIPT_DIR/.current-task"
CURRENT_PROGRESS_FILE="$SCRIPT_DIR/.current-progress"

TASK_NAME=""
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --task)
      TASK_NAME="$2"
      shift 2
      ;;
    --task=*)
      TASK_NAME="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        shift
      else
        echo "Error: Unknown argument '$1'"
        echo "Usage: ./run-task-loop.sh --task task-<name>.json [max_iterations]"
        exit 1
      fi
      ;;
  esac
done

if [ ! -d "$TASK_DIR" ]; then
  echo "Error: Tasks directory not found: $TASK_DIR"
  exit 1
fi

if [ -z "$TASK_NAME" ]; then
  shopt -s nullglob
  TASK_MATCHES=("$TASK_DIR"/task-*.json)
  shopt -u nullglob

  if [ "${#TASK_MATCHES[@]}" -eq 0 ]; then
    echo "Error: No task files found in $TASK_DIR"
    exit 1
  elif [ "${#TASK_MATCHES[@]}" -eq 1 ]; then
    TASK_FILE="${TASK_MATCHES[0]}"
  else
    echo "Error: --task is required when multiple task files exist."
    echo "Available tasks:"
    ls -1 "$TASK_DIR"/task-*.json 2>/dev/null | xargs -n 1 basename || true
    exit 1
  fi
else
  if [[ "$TASK_NAME" != *.json ]]; then
    TASK_NAME="task-$TASK_NAME.json"
  fi

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

echo "$TASK_FILE" > "$CURRENT_TASK_FILE"
echo "$PROGRESS_FILE" > "$CURRENT_PROGRESS_FILE"

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph+ Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "Task: $TASK_BASENAME" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph+ - Task: $TASK_BASENAME - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Ralph+ Iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph+ completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph+ reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
