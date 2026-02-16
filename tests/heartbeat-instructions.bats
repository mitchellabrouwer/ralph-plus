#!/usr/bin/env bats

setup() {
  TESTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
  AGENTS_DIR="$PROJECT_DIR/agents"
}

# --- Test 1: Each agent file contains ## Heartbeat Logging heading ---

@test "planner.md contains Heartbeat Logging heading" {
  grep -q '^## Heartbeat Logging' "$AGENTS_DIR/planner.md"
}

@test "tdd.md contains Heartbeat Logging heading" {
  grep -q '^## Heartbeat Logging' "$AGENTS_DIR/tdd.md"
}

@test "e2e.md contains Heartbeat Logging heading" {
  grep -q '^## Heartbeat Logging' "$AGENTS_DIR/e2e.md"
}

@test "quality-gate.md contains Heartbeat Logging heading" {
  grep -q '^## Heartbeat Logging' "$AGENTS_DIR/quality-gate.md"
}

@test "committer.md contains Heartbeat Logging heading" {
  grep -q '^## Heartbeat Logging' "$AGENTS_DIR/committer.md"
}

# --- Test 2: Each file contains the mktemp prepend pattern ---

@test "planner.md contains mktemp prepend pattern" {
  grep -q 'mktemp' "$AGENTS_DIR/planner.md"
  grep -q 'cat.*ACTIVITY_LOG_PATH' "$AGENTS_DIR/planner.md"
}

@test "tdd.md contains mktemp prepend pattern" {
  grep -q 'mktemp' "$AGENTS_DIR/tdd.md"
  grep -q 'cat.*ACTIVITY_LOG_PATH' "$AGENTS_DIR/tdd.md"
}

@test "e2e.md contains mktemp prepend pattern" {
  grep -q 'mktemp' "$AGENTS_DIR/e2e.md"
  grep -q 'cat.*ACTIVITY_LOG_PATH' "$AGENTS_DIR/e2e.md"
}

@test "quality-gate.md contains mktemp prepend pattern" {
  grep -q 'mktemp' "$AGENTS_DIR/quality-gate.md"
  grep -q 'cat.*ACTIVITY_LOG_PATH' "$AGENTS_DIR/quality-gate.md"
}

@test "committer.md contains mktemp prepend pattern" {
  grep -q 'mktemp' "$AGENTS_DIR/committer.md"
  grep -q 'cat.*ACTIVITY_LOG_PATH' "$AGENTS_DIR/committer.md"
}

# --- Test 3: Each file references ACTIVITY_LOG_PATH, ITERATION, STORY_ID ---

@test "planner.md references ACTIVITY_LOG_PATH, ITERATION, and STORY_ID" {
  grep -q 'ACTIVITY_LOG_PATH' "$AGENTS_DIR/planner.md"
  grep -q 'ITERATION' "$AGENTS_DIR/planner.md"
  grep -q 'STORY_ID' "$AGENTS_DIR/planner.md"
}

@test "tdd.md references ACTIVITY_LOG_PATH, ITERATION, and STORY_ID" {
  grep -q 'ACTIVITY_LOG_PATH' "$AGENTS_DIR/tdd.md"
  grep -q 'ITERATION' "$AGENTS_DIR/tdd.md"
  grep -q 'STORY_ID' "$AGENTS_DIR/tdd.md"
}

@test "e2e.md references ACTIVITY_LOG_PATH, ITERATION, and STORY_ID" {
  grep -q 'ACTIVITY_LOG_PATH' "$AGENTS_DIR/e2e.md"
  grep -q 'ITERATION' "$AGENTS_DIR/e2e.md"
  grep -q 'STORY_ID' "$AGENTS_DIR/e2e.md"
}

@test "quality-gate.md references ACTIVITY_LOG_PATH, ITERATION, and STORY_ID" {
  grep -q 'ACTIVITY_LOG_PATH' "$AGENTS_DIR/quality-gate.md"
  grep -q 'ITERATION' "$AGENTS_DIR/quality-gate.md"
  grep -q 'STORY_ID' "$AGENTS_DIR/quality-gate.md"
}

@test "committer.md references ACTIVITY_LOG_PATH, ITERATION, and STORY_ID" {
  grep -q 'ACTIVITY_LOG_PATH' "$AGENTS_DIR/committer.md"
  grep -q 'ITERATION' "$AGENTS_DIR/committer.md"
  grep -q 'STORY_ID' "$AGENTS_DIR/committer.md"
}

# --- Test 4: Each file has agent-specific example messages ---

@test "planner.md has planner-specific heartbeat examples" {
  grep -q 'planner: analyzing codebase' "$AGENTS_DIR/planner.md"
  grep -q 'planner: looking up docs' "$AGENTS_DIR/planner.md"
  grep -q 'planner: plan complete' "$AGENTS_DIR/planner.md"
}

@test "tdd.md has tdd-specific heartbeat examples" {
  grep -q 'tdd: writing tests for' "$AGENTS_DIR/tdd.md"
  grep -q 'tdd:.*tests passing' "$AGENTS_DIR/tdd.md"
  grep -q 'tdd: refactoring' "$AGENTS_DIR/tdd.md"
}

@test "e2e.md has e2e-specific heartbeat examples" {
  grep -q 'e2e: setting up browser' "$AGENTS_DIR/e2e.md"
  grep -q 'e2e: testing criterion' "$AGENTS_DIR/e2e.md"
  grep -q 'e2e: all criteria verified' "$AGENTS_DIR/e2e.md"
}

@test "quality-gate.md has quality-gate-specific heartbeat examples" {
  grep -q 'quality-gate: running typecheck' "$AGENTS_DIR/quality-gate.md"
  grep -q 'quality-gate: running lint' "$AGENTS_DIR/quality-gate.md"
  grep -q 'quality-gate: running tests' "$AGENTS_DIR/quality-gate.md"
}

@test "committer.md has committer-specific heartbeat examples" {
  grep -q 'committer: staging files' "$AGENTS_DIR/committer.md"
  grep -q 'committer: committing' "$AGENTS_DIR/committer.md"
  grep -q 'committer: updating progress log' "$AGENTS_DIR/committer.md"
}

# --- Test 5: Each heartbeat section is no more than 20 lines ---

@test "planner.md heartbeat section is at most 20 lines" {
  local count
  count=$(awk '/^## Heartbeat Logging/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' "$AGENTS_DIR/planner.md")
  [ "$count" -le 20 ]
  [ "$count" -gt 0 ]
}

@test "tdd.md heartbeat section is at most 20 lines" {
  local count
  count=$(awk '/^## Heartbeat Logging/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' "$AGENTS_DIR/tdd.md")
  [ "$count" -le 20 ]
  [ "$count" -gt 0 ]
}

@test "e2e.md heartbeat section is at most 20 lines" {
  local count
  count=$(awk '/^## Heartbeat Logging/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' "$AGENTS_DIR/e2e.md")
  [ "$count" -le 20 ]
  [ "$count" -gt 0 ]
}

@test "quality-gate.md heartbeat section is at most 20 lines" {
  local count
  count=$(awk '/^## Heartbeat Logging/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' "$AGENTS_DIR/quality-gate.md")
  [ "$count" -le 20 ]
  [ "$count" -gt 0 ]
}

@test "committer.md heartbeat section is at most 20 lines" {
  local count
  count=$(awk '/^## Heartbeat Logging/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' "$AGENTS_DIR/committer.md")
  [ "$count" -le 20 ]
  [ "$count" -gt 0 ]
}

# --- Test 6: Integration - all five agents covered ---

@test "all five agent files exist and have heartbeat sections" {
  local agents=("planner.md" "tdd.md" "e2e.md" "quality-gate.md" "committer.md")
  local count=0
  for agent in "${agents[@]}"; do
    grep -q '^## Heartbeat Logging' "$AGENTS_DIR/$agent"
    count=$((count + 1))
  done
  [ "$count" -eq 5 ]
}
