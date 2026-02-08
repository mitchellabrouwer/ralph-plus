#!/bin/bash
# Interactive task dashboard - view stories, toggle status, edit notes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="${TASK_DIR:-$SCRIPT_DIR/../docs/tasks}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

TASK_FILE=""

list_tasks() {
  local f
  for f in "$TASK_DIR"/task-*.json; do
    [ -e "$f" ] && basename "$f"
  done
}

task_count() {
  list_tasks | wc -l | tr -d ' '
}

clear_screen() {
  printf '\033[2J\033[H'
}

draw_line() {
  local char="${1:-─}"
  local width="${2:-45}"
  local line=""
  for ((i = 0; i < width; i++)); do
    line+="$char"
  done
  echo "$line"
}

risk_color() {
  case "$1" in
    low) echo -e "${GREEN}$1${RESET}" ;;
    medium) echo -e "${YELLOW}$1${RESET}" ;;
    high) echo -e "${RED}$1${RESET}" ;;
    *) echo "$1" ;;
  esac
}

show_overview() {
  clear_screen

  local filename
  filename=$(basename "$TASK_FILE")
  local total
  total=$(jq '.userStories | length' "$TASK_FILE")
  local passing
  passing=$(jq '[.userStories[] | select(.passes == true)] | length' "$TASK_FILE")

  echo ""
  printf "  ${BOLD}"
  draw_line "═" 45
  printf "${RESET}"
  echo ""
  printf "  ${BOLD}%-30s${RESET} ${GREEN}%s${RESET}/${BOLD}%s${RESET} stories passing\n" "$filename" "$passing" "$total"
  printf "  ${BOLD}"
  draw_line "═" 45
  printf "${RESET}"
  echo ""
  echo ""
  echo "  Stories:"

  local i=0
  while IFS= read -r line; do
    local id title passes risk
    id=$(echo "$line" | jq -r '.id')
    title=$(echo "$line" | jq -r '.title')
    passes=$(echo "$line" | jq -r '.passes')
    risk=$(echo "$line" | jq -r '.risk // empty')

    i=$((i + 1))

    local bullet
    if [ "$passes" = "true" ]; then
      bullet="${GREEN}●${RESET}"
    else
      bullet="${RED}○${RESET}"
    fi

    local risk_str=""
    if [ -n "$risk" ]; then
      risk_str=" [$(risk_color "$risk")]"
    fi

    printf "  %b %-7s %-36s%b\n" "$bullet" "$id" "$title" "$risk_str"
  done < <(jq -c '.userStories[]' "$TASK_FILE")

  echo ""
  printf "  ${DIM}"
  draw_line "─" 45
  printf "${RESET}"
  echo ""
  printf "  ${DIM}Commands:${RESET}\n"
  printf "  ${CYAN}[1-%d]${RESET} View story details    ${CYAN}[t #]${RESET} Toggle pass/fail\n" "$total"
  printf "  ${CYAN}[g]${RESET}   Activity log           ${CYAN}[r]${RESET}   Refresh\n"
  if [ "$(task_count)" -gt 1 ]; then
    printf "  ${CYAN}[a]${RESET}   All tasks              ${CYAN}[q]${RESET}   Quit\n"
  else
    printf "  ${CYAN}[l]${RESET}   Load different task    ${CYAN}[q]${RESET}   Quit\n"
  fi
  echo ""
}

show_log() {
  clear_screen

  local task_basename task_slug activity_log
  task_basename=$(basename "$TASK_FILE")
  task_slug="${task_basename#task-}"
  task_slug="${task_slug%.json}"
  activity_log="$TASK_DIR/activity-$task_slug.log"

  echo ""
  printf "  ${BOLD}Activity Log${RESET} ${DIM}($task_basename)${RESET}\n"
  printf "  ${BOLD}"
  draw_line "─" 45
  printf "${RESET}"
  echo ""

  if [ -f "$activity_log" ]; then
    head -20 "$activity_log" | while IFS= read -r line; do
      printf "  ${DIM}%s${RESET}\n" "$line"
    done
  else
    printf "  ${DIM}No activity log yet.${RESET}\n"
  fi

  echo ""
  printf "  ${DIM}"
  draw_line "─" 45
  printf "${RESET}"
  echo ""
  printf "  ${CYAN}[b]${RESET} Back  ${CYAN}[r]${RESET} Refresh\n"
  echo ""
}

log_loop() {
  while true; do
    show_log
    printf "  > "
    read -r cmd
    case "$cmd" in
      b|B) return ;;
      r|R) continue ;;
      q|Q) exit 0 ;;
      *) ;;
    esac
  done
}

show_multi_task_overview() {
  clear_screen

  echo ""
  printf "  ${BOLD}"
  draw_line "=" 45
  printf "${RESET}"
  echo ""
  printf "  ${BOLD}All Tasks${RESET}\n"
  printf "  ${BOLD}"
  draw_line "=" 45
  printf "${RESET}"
  echo ""
  echo ""

  TASK_LIST=()
  local i=1
  while IFS= read -r task_name; do
    TASK_LIST+=("$task_name")
    local task_path="$TASK_DIR/$task_name"
    local total passing
    total=$(jq '.userStories | length' "$task_path")
    passing=$(jq '[.userStories[] | select(.passes == true)] | length' "$task_path")

    local color
    if [ "$passing" -eq "$total" ]; then
      color="$GREEN"
    elif [ "$passing" -eq 0 ]; then
      color="$RED"
    else
      color="$YELLOW"
    fi

    printf "  ${CYAN}[%d]${RESET} %-30s %b%s/%s passing${RESET}\n" "$i" "$task_name" "$color" "$passing" "$total"
    i=$((i + 1))
  done < <(list_tasks)

  if [ "${#TASK_LIST[@]}" -eq 0 ]; then
    printf "  ${DIM}No tasks found${RESET}\n"
  fi

  echo ""
  printf "  ${DIM}"
  draw_line "-" 45
  printf "${RESET}"
  echo ""
  printf "  ${DIM}Commands:${RESET}\n"
  printf "  ${CYAN}[1-%d]${RESET} Select task    ${CYAN}[r]${RESET} Refresh    ${CYAN}[q]${RESET} Quit\n" "${#TASK_LIST[@]}"
  echo ""
}

multi_task_loop() {
  while true; do
    show_multi_task_overview
    printf "  > "
    read -r cmd

    # Numeric selection
    if [[ "$cmd" =~ ^[0-9]+$ ]]; then
      if [ "$cmd" -ge 1 ] && [ "$cmd" -le "${#TASK_LIST[@]}" ]; then
        TASK_FILE="$TASK_DIR/${TASK_LIST[$((cmd - 1))]}"
        main_loop
      fi
      continue
    fi

    case "$cmd" in
      r|R) continue ;;
      q|Q) exit 0 ;;
      *) ;;
    esac
  done
}

show_story() {
  local index=$1
  clear_screen

  local story
  story=$(jq -c ".userStories[$index]" "$TASK_FILE")

  if [ "$story" = "null" ] || [ -z "$story" ]; then
    echo "  Story not found."
    return 1
  fi

  local id title description passes risk priority notes
  id=$(echo "$story" | jq -r '.id')
  title=$(echo "$story" | jq -r '.title')
  description=$(echo "$story" | jq -r '.description // empty')
  passes=$(echo "$story" | jq -r '.passes')
  risk=$(echo "$story" | jq -r '.risk // empty')
  priority=$(echo "$story" | jq -r '.priority // empty')
  notes=$(echo "$story" | jq -r '.notes // empty')

  local status_str
  if [ "$passes" = "true" ]; then
    status_str="${GREEN}● Passing${RESET}"
  else
    status_str="${RED}○ Failing${RESET}"
  fi

  echo ""
  printf "  ${BOLD}▶ %s: %s${RESET}\n" "$id" "$title"
  printf "  "
  draw_line "─" 45
  echo ""

  printf "  Status:   %b\n" "$status_str"
  if [ -n "$risk" ]; then
    printf "  Risk:     %b\n" "$(risk_color "$risk")"
  fi
  if [ -n "$priority" ]; then
    printf "  Priority: %s\n" "$priority"
  fi

  if [ -n "$description" ]; then
    echo ""
    printf "  ${BOLD}Description:${RESET}\n"
    echo "$description" | fold -s -w 50 | while IFS= read -r line; do
      printf "    %s\n" "$line"
    done
  fi

  local ac_count
  ac_count=$(echo "$story" | jq '.acceptanceCriteria | length')
  if [ "$ac_count" -gt 0 ]; then
    echo ""
    printf "  ${BOLD}Acceptance Criteria:${RESET}\n"
    for ((j = 0; j < ac_count; j++)); do
      local criterion
      criterion=$(echo "$story" | jq -r ".acceptanceCriteria[$j]")
      printf "    [ ] %s\n" "$criterion"
    done
  fi

  echo ""
  if [ -n "$notes" ]; then
    printf "  ${BOLD}Notes:${RESET} %s\n" "$notes"
  else
    printf "  ${BOLD}Notes:${RESET} ${DIM}(none)${RESET}\n"
  fi

  echo ""
  printf "  ${DIM}"
  draw_line "─" 45
  printf "${RESET}"
  echo ""
  printf "  ${CYAN}[b]${RESET} Back  ${CYAN}[t]${RESET} Toggle pass/fail  ${CYAN}[n]${RESET} Edit notes\n"
  echo ""
}

toggle_pass() {
  local index=$1
  local current
  current=$(jq ".userStories[$index].passes" "$TASK_FILE")
  local new_val
  if [ "$current" = "true" ]; then
    new_val="false"
  else
    new_val="true"
  fi

  local tmp
  tmp=$(mktemp)
  jq ".userStories[$index].passes = $new_val" "$TASK_FILE" > "$tmp" && mv "$tmp" "$TASK_FILE"
}

edit_notes() {
  local index=$1
  local current
  current=$(jq -r ".userStories[$index].notes // empty" "$TASK_FILE")

  if [ -n "$current" ]; then
    printf "  Current notes: %s\n" "$current"
  fi
  printf "  Enter new notes (empty to clear): "
  read -r new_notes

  local tmp
  tmp=$(mktemp)
  jq --arg notes "$new_notes" ".userStories[$index].notes = \$notes" "$TASK_FILE" > "$tmp" && mv "$tmp" "$TASK_FILE"
}

load_task() {
  local count
  count=$(task_count)

  if [ "$count" -eq 0 ]; then
    echo "  No task files found in $TASK_DIR"
    printf "  Press any key to continue..."
    read -rsn1
    return 1
  fi

  echo ""
  echo "  Available tasks:"
  echo ""

  local tasks=()
  local i=1
  while IFS= read -r prd; do
    tasks+=("$prd")
    printf "  ${CYAN}[%d]${RESET} %s\n" "$i" "$prd"
    i=$((i + 1))
  done < <(list_tasks)

  echo ""
  printf "  Select task number: "
  read -r choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tasks[@]}" ]; then
    TASK_FILE="$TASK_DIR/${tasks[$((choice - 1))]}"
    return 0
  else
    echo "  Invalid selection."
    printf "  Press any key to continue..."
    read -rsn1
    return 1
  fi
}

story_detail_loop() {
  local index=$1
  while true; do
    show_story "$index"
    printf "  > "
    read -r cmd

    case "$cmd" in
      b|B) return ;;
      t|T)
        toggle_pass "$index"
        ;;
      n|N)
        edit_notes "$index"
        ;;
      q|Q) exit 0 ;;
      *) ;;
    esac
  done
}

main_loop() {
  local total
  while true; do
    show_overview
    total=$(jq '.userStories | length' "$TASK_FILE")
    printf "  > "
    read -r cmd

    # Toggle: "t 3" or "t3"
    if [[ "$cmd" =~ ^[tT][[:space:]]*([0-9]+)$ ]]; then
      local num="${BASH_REMATCH[1]}"
      if [ "$num" -ge 1 ] && [ "$num" -le "$total" ]; then
        toggle_pass $((num - 1))
      fi
      continue
    fi

    # Story number
    if [[ "$cmd" =~ ^[0-9]+$ ]]; then
      if [ "$cmd" -ge 1 ] && [ "$cmd" -le "$total" ]; then
        story_detail_loop $((cmd - 1))
      fi
      continue
    fi

    case "$cmd" in
      a|A) return ;;
      g|G) log_loop ;;
      l|L)
        clear_screen
        if load_task; then
          continue
        fi
        ;;
      r|R) continue ;;
      q|Q) exit 0 ;;
      *) ;;
    esac
  done
}

# --- Entry point ---

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required"
  exit 1
fi

if [ ! -d "$TASK_DIR" ]; then
  echo "Error: Tasks directory not found: $TASK_DIR"
  exit 1
fi

# --list: preserve original behavior
if [ "$1" = "--list" ]; then
  list_tasks
  exit 0
fi

# Explicit file argument
if [ -n "$1" ]; then
  TASK_NAME="$1"
  if [[ "$TASK_NAME" != *.json ]]; then
    TASK_NAME="task-$TASK_NAME.json"
  fi
  if [[ "$TASK_NAME" == */* ]]; then
    TASK_FILE="$TASK_NAME"
  else
    TASK_FILE="$TASK_DIR/$TASK_NAME"
  fi

  if [ ! -f "$TASK_FILE" ]; then
    echo "Error: Task file not found: $TASK_FILE"
    echo "Available tasks:"
    list_tasks
    exit 1
  fi

  main_loop
fi

# No argument: auto-load if single task exists, else prompt
count=$(task_count)

if [ "$count" -eq 0 ]; then
  echo "No task files found in $TASK_DIR"
  exit 1
elif [ "$count" -eq 1 ]; then
  TASK_FILE="$TASK_DIR/$(list_tasks)"
  main_loop
else
  multi_task_loop
fi

fi
