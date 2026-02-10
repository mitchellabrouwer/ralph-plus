#!/bin/bash
# Common test setup for dashboard.sh bats tests

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"
DASHBOARD="$PROJECT_DIR/ralph-plus/dashboard.sh"

# Source dashboard.sh functions (requires BASH_SOURCE guard in dashboard.sh)
setup_dashboard() {
  # shellcheck source=../../ralph-plus/dashboard.sh
  source "$DASHBOARD"
  # Override TASK_DIR after sourcing (source sets it from SCRIPT_DIR)
  TASK_DIR="$FIXTURES_DIR"
  SEL_MAIN=0
  SEL_MULTI=0
}

# Strip ANSI color codes from output for easier assertions
strip_colors() {
  sed 's/\x1b\[[0-9;]*m//g'
}
