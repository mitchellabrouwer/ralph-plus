#!/usr/bin/env bats

setup() {
  TESTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
  CLAUDE_MD="$PROJECT_DIR/ralph-plus/CLAUDE.md"
}

# --- Unit tests ---

@test "CLAUDE.md contains 'Context to pass to every agent' heading" {
  grep -q '^### Context to pass to every agent' "$CLAUDE_MD"
}

@test "Context subsection is inside Pipeline section" {
  local content
  content=$(awk '/^## Pipeline/{found=1} found && /^## [^#]/{if(++c>1) exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q '### Context to pass to every agent'
}

@test "Context subsection specifies Activity log with .current-activity-log reference" {
  local content
  content=$(awk '/^### Context to pass to every agent/{found=1} found && /^###? / && !/^### Context/{exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q 'Activity log'
  echo "$content" | grep -q '\.current-activity-log'
}

@test "Context subsection specifies Iteration with .current-iteration reference" {
  local content
  content=$(awk '/^### Context to pass to every agent/{found=1} found && /^###? / && !/^### Context/{exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q 'Iteration'
  echo "$content" | grep -q '\.current-iteration'
}

@test "Context subsection specifies Story with story ID reference" {
  local content
  content=$(awk '/^### Context to pass to every agent/{found=1} found && /^###? / && !/^### Context/{exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q 'Story'
  echo "$content" | grep -qi 'story ID\|story id'
}

@test "Context subsection uses explicit format with all three values" {
  local content
  content=$(awk '/^### Context to pass to every agent/{found=1} found && /^###? / && !/^### Context/{exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q 'Include these lines at the top of every agent Task prompt'
}

@test "Context subsection appears before agent definitions" {
  local context_line
  context_line=$(grep -n '^### Context to pass to every agent' "$CLAUDE_MD" | head -1 | cut -d: -f1)
  local planner_line
  planner_line=$(grep -n '^### 1\. Planner' "$CLAUDE_MD" | head -1 | cut -d: -f1)
  [ "$context_line" -lt "$planner_line" ]
}

@test "Context subsection appears exactly once" {
  local count
  count=$(grep -c '### Context to pass to every agent' "$CLAUDE_MD")
  [ "$count" -eq 1 ]
}

# --- Integration tests ---

@test "Pipeline section still contains all five agent subsections" {
  local content
  content=$(awk '/^## Pipeline/{found=1} found && /^## [^#]/{if(++c>1) exit} found{print}' "$CLAUDE_MD")
  echo "$content" | grep -q '### 1\. Planner'
  echo "$content" | grep -q '### 2\. TDD'
  echo "$content" | grep -q '### 3\. E2E'
  echo "$content" | grep -q '### 4\. Quality Gate'
  echo "$content" | grep -q '### 5\. Committer'
}

@test "Planner agent instructions unchanged" {
  grep -q 'Spawn `planner`. Pass: story details, PRD path, quality gates, codebase patterns from progress log.' "$CLAUDE_MD"
  grep -q 'Returns: files to change, ordered steps, test strategy, risk areas.' "$CLAUDE_MD"
}

@test "TDD agent instructions unchanged" {
  grep -q 'Spawn `tdd`. Pass: story details, planner'\''s full output.' "$CLAUDE_MD"
  grep -q 'Red-Green-Refactor cycle. Returns: what was created/modified, test results.' "$CLAUDE_MD"
}

@test "Committer agent instructions unchanged" {
  grep -q 'Only if quality-gate passed. Spawn `committer` with `model: "haiku"`. Pass: story id/title, files changed, implementation summary.' "$CLAUDE_MD"
  grep -q 'Commits, sets `passes: true`, appends learnings to progress log.' "$CLAUDE_MD"
}

@test "Context is not repeated per agent subsection" {
  local agents=("### 1. Planner" "### 2. TDD" "### 3. E2E" "### 4. Quality Gate" "### 5. Committer")
  for agent in "${agents[@]}"; do
    local content
    content=$(awk -v hdr="$agent" '$0 ~ hdr{found=1; next} found && /^### /{exit} found{print}' "$CLAUDE_MD")
    ! echo "$content" | grep -q 'Activity log.*\.current-activity-log'
    ! echo "$content" | grep -q 'Iteration.*\.current-iteration'
  done
}
