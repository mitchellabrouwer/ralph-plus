#!/bin/bash
# sync-codex-agents.sh
# Generates .codex/ config from agents/*.md (Claude agent definitions)
# Run from ralph-plus repo root after editing any agent definition.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_DIR="$SCRIPT_DIR/.codex"
CODEX_AGENTS_DIR="$CODEX_DIR/agents"

if [ ! -d "$AGENTS_DIR" ]; then
  echo "Error: agents/ directory not found at $AGENTS_DIR"
  exit 1
fi

mkdir -p "$CODEX_AGENTS_DIR"

# Only haiku-mapped agents get an explicit lighter model.
# opus/sonnet agents inherit the global model from ~/.codex/config.toml.
map_model_line() {
  case "$1" in
    haiku) echo 'model = "gpt-4o-mini"' ;;
    *)     echo "" ;;
  esac
}

map_reasoning_effort() {
  case "$1" in
    opus)   echo "high" ;;
    sonnet) echo "medium" ;;
    haiku)  echo "low" ;;
    *)      echo "medium" ;;
  esac
}

# Start .codex/config.toml
cat > "$CODEX_DIR/config.toml" << 'HEADER'
# Auto-generated from agents/*.md by sync-codex-agents.sh
# Re-run after editing agent definitions. Do not edit manually.

[features]
multi_agent = true

HEADER

count=0
for md in "$AGENTS_DIR"/*.md; do
  [ -f "$md" ] || continue
  slug=$(basename "$md" .md)

  # Parse YAML frontmatter
  model=$(awk '/^---$/{n++; next} n==1 && /^model:/{print $2; exit}' "$md")

  # Extract first sentence of description (before first \n)
  desc=$(awk '/^---$/{n++; next} n==1 && /^description:/{
    sub(/^description: *"?/, "")
    sub(/"$/, "")
    sub(/\\n.*/, "")
    print
    exit
  }' "$md")

  # Extract body (everything after second ---)
  body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$md")

  model_line=$(map_model_line "$model")
  reasoning=$(map_reasoning_effort "$model")

  # Append agent role to config.toml
  cat >> "$CODEX_DIR/config.toml" << EOF
[agents.$slug]
description = """$desc"""
config_file = "agents/$slug.toml"

EOF

  # Write agent TOML config
  {
    [ -n "$model_line" ] && echo "$model_line"
    echo "model_reasoning_effort = \"$reasoning\""
    echo 'sandbox_mode = "workspace-write"'
    cat << INSTRUCTIONS
developer_instructions = """
$body"""
INSTRUCTIONS
  } > "$CODEX_AGENTS_DIR/$slug.toml"

  if [ -n "$model_line" ]; then
    echo "  $slug (claude:$model -> codex:gpt-4o-mini, effort:$reasoning)"
  else
    echo "  $slug (claude:$model -> inherits global, effort:$reasoning)"
  fi
  count=$((count + 1))
done

echo ""
echo "Synced $count agents:"
echo "  $CODEX_DIR/config.toml"
echo "  $CODEX_AGENTS_DIR/*.toml"
