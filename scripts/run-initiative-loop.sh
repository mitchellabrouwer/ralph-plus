#!/bin/bash
# Ralph+ - Multi-agent pipeline for autonomous story implementation
# Usage: ./run-initiative-loop.sh --prd prd-<initiative>.json [max_iterations]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_DIR="$SCRIPT_DIR/../docs/initiatives"
CURRENT_PRD_FILE="$SCRIPT_DIR/.current-prd"
CURRENT_PROGRESS_FILE="$SCRIPT_DIR/.current-progress"

PRD_NAME=""
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --prd)
      PRD_NAME="$2"
      shift 2
      ;;
    --prd=*)
      PRD_NAME="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        shift
      else
        echo "Error: Unknown argument '$1'"
        echo "Usage: ./run-initiative-loop.sh --prd prd-<initiative>.json [max_iterations]"
        exit 1
      fi
      ;;
  esac
done

if [ ! -d "$PRD_DIR" ]; then
  echo "Error: PRD directory not found: $PRD_DIR"
  exit 1
fi

if [ -z "$PRD_NAME" ]; then
  shopt -s nullglob
  PRD_MATCHES=("$PRD_DIR"/prd-*.json)
  shopt -u nullglob

  if [ "${#PRD_MATCHES[@]}" -eq 0 ]; then
    echo "Error: No PRD files found in $PRD_DIR"
    exit 1
  elif [ "${#PRD_MATCHES[@]}" -eq 1 ]; then
    PRD_FILE="${PRD_MATCHES[0]}"
  else
    echo "Error: --prd is required when multiple PRDs exist."
    echo "Available PRDs:"
    ls -1 "$PRD_DIR"/prd-*.json 2>/dev/null | xargs -n 1 basename || true
    exit 1
  fi
else
  if [[ "$PRD_NAME" != *.json ]]; then
    PRD_NAME="prd-$PRD_NAME.json"
  fi

  if [[ "$PRD_NAME" == */* ]]; then
    PRD_FILE="$PRD_NAME"
  else
    PRD_FILE="$PRD_DIR/$PRD_NAME"
  fi
fi

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  echo "Available PRDs:"
  ls -1 "$PRD_DIR"/prd-*.json 2>/dev/null | xargs -n 1 basename || true
  exit 1
fi

PRD_BASENAME=$(basename "$PRD_FILE")
PRD_SLUG="${PRD_BASENAME#prd-}"
PRD_SLUG="${PRD_SLUG%.json}"
PROGRESS_FILE="$PRD_DIR/progress-$PRD_SLUG.txt"

echo "$PRD_FILE" > "$CURRENT_PRD_FILE"
echo "$PROGRESS_FILE" > "$CURRENT_PROGRESS_FILE"

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph+ Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "PRD: $PRD_BASENAME" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph+ - PRD: $PRD_BASENAME - Max iterations: $MAX_ITERATIONS"

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
