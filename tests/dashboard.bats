#!/usr/bin/env bats

setup() {
  load test_helper/common-setup
  setup_dashboard
}

@test "list_tasks returns basenames of task files" {
  run list_tasks
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "task-alpha.json"
  echo "$output" | grep -q "task-beta.json"
  echo "$output" | grep -q "task-gamma.json"
}

@test "task_count returns correct count" {
  run task_count
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "show_multi_task_overview lists all task files" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "task-alpha.json"
  echo "$stripped" | grep -q "task-beta.json"
  echo "$stripped" | grep -q "task-gamma.json"
}

@test "show_multi_task_overview shows correct pass counts" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # alpha: 2 passing out of 3
  echo "$stripped" | grep "task-alpha.json" | grep -q "2/3 passing"
  # beta: 2 passing out of 2
  echo "$stripped" | grep "task-beta.json" | grep -q "2/2 passing"
  # gamma: 0 passing out of 4
  echo "$stripped" | grep "task-gamma.json" | grep -q "0/4 passing"
}

@test "show_multi_task_overview color codes fully passing as green" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  # beta is fully passing (2/2) - should have green ANSI code
  local beta_line
  beta_line=$(echo "$output" | grep "task-beta.json")
  echo "$beta_line" | grep -q $'\033\[0;32m'
}

@test "show_multi_task_overview color codes partial as yellow" {
  SEL_MULTI=1
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  # alpha is partial (2/3) - should have yellow ANSI code (not selected)
  local alpha_line
  alpha_line=$(echo "$output" | grep "task-alpha.json")
  echo "$alpha_line" | grep -q $'\033\[0;33m'
}

@test "show_multi_task_overview color codes zero passing as red" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  # gamma is zero passing (0/4) - should have red ANSI code
  local gamma_line
  gamma_line=$(echo "$output" | grep "task-gamma.json")
  echo "$gamma_line" | grep -q $'\033\[0;31m'
}

@test "show_multi_task_overview populates TASK_LIST array" {
  # Cannot use 'run' for this since we need to check the global array
  show_multi_task_overview > /dev/null 2>&1
  [ "${#TASK_LIST[@]}" -eq 3 ]
  [ "${TASK_LIST[0]}" = "task-alpha.json" ]
  [ "${TASK_LIST[1]}" = "task-beta.json" ]
  [ "${TASK_LIST[2]}" = "task-gamma.json" ]
}

@test "show_multi_task_overview handles empty task directory" {
  local empty_dir
  empty_dir=$(mktemp -d)
  TASK_DIR="$empty_dir"
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "No tasks found"
  rm -rf "$empty_dir"
}

# --- Integration tests ---

@test "dashboard shows multi-task screen with multiple tasks" {
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< 'q'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "All Tasks"
  echo "$stripped" | grep -q "task-alpha.json"
  echo "$stripped" | grep -q "task-beta.json"
  echo "$stripped" | grep -q "task-gamma.json"
}

@test "selecting task enters story overview" {
  # j to move down, l to open (beta), q to quit
  local input
  input=$(printf 'jlq')
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< '$input'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should show the beta task story overview
  echo "$stripped" | grep -q "task-beta.json"
  echo "$stripped" | grep -q "stories passing"
}

@test "pressing h returns to multi-task overview from story overview" {
  # l to open first task (alpha), h to go back, q to quit
  local input
  input=$(printf 'lhq')
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< '$input'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should show All Tasks screen again after pressing 'h'
  # The output should contain "All Tasks" at least twice (initial + return)
  local count
  count=$(echo "$stripped" | grep -c "All Tasks")
  [ "$count" -ge 2 ]
}

@test "single task skips multi-task screen" {
  # Create a directory with just one task file
  local single_dir
  single_dir=$(mktemp -d)
  cp "$FIXTURES_DIR/task-alpha.json" "$single_dir/"
  run bash -c "TASK_DIR='$single_dir' bash '$DASHBOARD' <<< 'q'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should NOT show All Tasks screen
  ! echo "$stripped" | grep -q "All Tasks"
  # Should show the story overview directly
  echo "$stripped" | grep -q "task-alpha.json"
  echo "$stripped" | grep -q "stories passing"
  rm -rf "$single_dir"
}

@test "explicit file argument skips multi-task screen" {
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' '$FIXTURES_DIR/task-beta.json' <<< 'q'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should NOT show All Tasks
  ! echo "$stripped" | grep -q "All Tasks"
  # Should show beta task overview directly
  echo "$stripped" | grep -q "task-beta.json"
}

@test "list flag still works" {
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' --list"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "task-alpha.json"
  echo "$output" | grep -q "task-beta.json"
  echo "$output" | grep -q "task-gamma.json"
}

@test "show_overview shows back command when multiple tasks exist" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -qi "back"
}

# --- Pipeline status tests ---

@test "get_pipeline_status parses story and agent from activity log" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  get_pipeline_status
  [ "$PIPELINE_STORY" = "US-001" ]
  [ "$PIPELINE_AGENT" = "tdd" ]
  [ "$PIPELINE_MESSAGE" = "starting" ]
}

@test "get_pipeline_status extracts iteration from log entry" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  get_pipeline_status
  [ "$PIPELINE_ITERATION" = "1/10" ]
}

@test "get_pipeline_status marks old entries as inactive" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  # Fixture has 2025 timestamps, well past 5 minutes
  get_pipeline_status
  [ "$PIPELINE_ACTIVE" = false ]
}

@test "get_pipeline_status handles missing activity log" {
  TASK_FILE="$FIXTURES_DIR/task-gamma.json"
  get_pipeline_status
  [ "$PIPELINE_ACTIVE" = false ]
  [ -z "$PIPELINE_STORY" ]
}

@test "draw_status_bar outputs nothing when no pipeline data" {
  PIPELINE_STORY=""
  run draw_status_bar
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "draw_status_bar shows IDLE for inactive pipeline" {
  PIPELINE_ACTIVE=false
  PIPELINE_STORY="US-001"
  PIPELINE_AGENT="tdd"
  PIPELINE_MESSAGE="starting"
  PIPELINE_ITERATION="1/10"
  PIPELINE_AGO="2h ago"
  run draw_status_bar
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "IDLE"
  echo "$stripped" | grep -q "Iteration 1/10"
  echo "$stripped" | grep -q "US-001 tdd: starting"
}

# --- Progress bar tests ---

@test "draw_progress_bar shows correct fill for partial progress" {
  run draw_progress_bar 2 3
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "2/3"
  # Should contain both filled and empty chars
  echo "$stripped" | grep -q "█"
  echo "$stripped" | grep -q "░"
}

@test "draw_progress_bar all green when complete" {
  run draw_progress_bar 3 3
  [ "$status" -eq 0 ]
  # Should use green color code
  echo "$output" | grep -q $'\033\[0;32m'
}

@test "draw_progress_bar all red when zero" {
  run draw_progress_bar 0 4
  [ "$status" -eq 0 ]
  # Should use red color code
  echo "$output" | grep -q $'\033\[0;31m'
}

# --- Activity feed tests ---

@test "draw_activity_feed shows recent entries" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run draw_activity_feed
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "Recent Activity"
  echo "$stripped" | grep -q "12:22:20"
  echo "$stripped" | grep -q "tdd: starting"
}

@test "draw_activity_feed strips date portion" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run draw_activity_feed
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should NOT contain the date portion
  ! echo "$stripped" | grep -q "2025-06-15"
}

@test "draw_activity_feed outputs nothing with no log file" {
  TASK_FILE="$FIXTURES_DIR/task-gamma.json"
  run draw_activity_feed
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- Show overview new features ---

@test "show_overview shows percentage" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "66%"
}

@test "show_overview shows progress bar" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "█"
}

@test "show_overview includes activity feed" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "Recent Activity"
}

@test "show_overview uses dim bullet for non-passing non-active stories" {
  TASK_FILE="$FIXTURES_DIR/task-gamma.json"
  SEL_MAIN=1
  run show_overview
  [ "$status" -eq 0 ]
  # gamma has no activity log so pipeline is not active
  # US-001 is not selected (SEL_MAIN=1), should use DIM color (\033[2m)
  echo "$output" | grep "US-001" | grep -q $'\033\[2m'
}

# --- US-001: Arrow key removal tests ---

@test "show_overview help text does not reference arrows" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  ! echo "$stripped" | grep -qi "arrow"
}

@test "show_multi_task_overview help text does not reference arrows" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  ! echo "$stripped" | grep -qi "arrow"
}

@test "show_overview help text shows j/k navigate without arrows" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "j/k navigate"
}

@test "show_multi_task_overview help text shows j/k navigate without arrows" {
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "j/k navigate"
}

@test "main_loop case branches do not match arrow keys" {
  local func_body
  func_body=$(declare -f main_loop)
  # declare -f reformats case patterns with spaces: j | J | DOWN)
  ! echo "$func_body" | grep -q 'DOWN)'
  ! echo "$func_body" | grep -q 'UP)'
  ! echo "$func_body" | grep -q 'RIGHT'
  ! echo "$func_body" | grep -q 'LEFT'
}

@test "multi_task_loop case branches do not match arrow keys" {
  local func_body
  func_body=$(declare -f multi_task_loop)
  ! echo "$func_body" | grep -q 'DOWN)'
  ! echo "$func_body" | grep -q 'UP)'
  ! echo "$func_body" | grep -q 'RIGHT'
}

@test "story_detail_loop case branches do not match LEFT arrow key" {
  local func_body
  func_body=$(declare -f story_detail_loop)
  ! echo "$func_body" | grep -q 'LEFT'
}

@test "log_loop case branches do not match LEFT arrow key" {
  local func_body
  func_body=$(declare -f log_loop)
  ! echo "$func_body" | grep -q 'LEFT'
}

@test "read_key function still returns arrow key names" {
  local func_body
  func_body=$(declare -f read_key)
  echo "$func_body" | grep -q '"UP"'
  echo "$func_body" | grep -q '"DOWN"'
  echo "$func_body" | grep -q '"LEFT"'
  echo "$func_body" | grep -q '"RIGHT"'
}

@test "j/k navigation still works in multi-task loop" {
  # j to move to second task, l to open, q to quit
  local input
  input=$(printf 'jlq')
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< '$input'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should have opened beta (second task) and show stories passing
  echo "$stripped" | grep -q "task-beta.json"
  echo "$stripped" | grep -q "stories passing"
}
