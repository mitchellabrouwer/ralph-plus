#!/bin/bash
# View a PRD JSON file with color and vim style navigation via less

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_DIR="$SCRIPT_DIR/../docs/initiatives"

usage() {
  echo "Usage: ./initiative-browser.sh --list | ./initiative-browser.sh prd-<initiative>.json"
}

list_prds() {
  ls -1 "$PRD_DIR"/prd-*.json 2>/dev/null | xargs -n 1 basename
}

if [ ! -d "$PRD_DIR" ]; then
  echo "Error: PRD directory not found: $PRD_DIR"
  exit 1
fi

if [ "$1" = "--list" ]; then
  list_prds
  exit 0
fi

if [ -z "$1" ]; then
  usage
  echo "Available PRDs:"
  list_prds
  exit 1
fi

PRD_NAME="$1"
if [[ "$PRD_NAME" != *.json ]]; then
  PRD_NAME="prd-$PRD_NAME.json"
fi

if [[ "$PRD_NAME" == */* ]]; then
  PRD_FILE="$PRD_NAME"
else
  PRD_FILE="$PRD_DIR/$PRD_NAME"
fi

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  echo "Available PRDs:"
  list_prds
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to view PRDs"
  exit 1
fi

jq -C . "$PRD_FILE" | less -R
