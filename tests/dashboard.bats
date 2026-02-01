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
  run show_multi_task_overview
  [ "$status" -eq 0 ]
  # alpha is partial (2/3) - should have yellow ANSI code
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

@test "selecting task number enters story overview" {
  # Select task 2 (beta), then quit
  local input
  input=$(printf "2\nq\n")
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< '$input'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should show the beta task story overview
  echo "$stripped" | grep -q "task-beta.json"
  echo "$stripped" | grep -q "stories passing"
}

@test "pressing a returns to multi-task overview from story overview" {
  # Select task 1 (alpha), press 'a' to go back, then quit
  local input
  input=$(printf "1\na\nq\n")
  run bash -c "TASK_DIR='$FIXTURES_DIR' bash '$DASHBOARD' <<< '$input'"
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  # Should show All Tasks screen again after pressing 'a'
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

@test "show_overview shows all tasks command when multiple tasks exist" {
  TASK_FILE="$FIXTURES_DIR/task-alpha.json"
  run show_overview
  [ "$status" -eq 0 ]
  local stripped
  stripped=$(echo "$output" | strip_colors)
  echo "$stripped" | grep -q "All tasks"
}
