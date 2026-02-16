#!/bin/bash
# Interactive task dashboard - view stories, toggle status, edit notes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="${TASK_DIR:-$SCRIPT_DIR/../docs/tasks}"
VERSION=$(cat "$SCRIPT_DIR/.version" 2>/dev/null || echo "dev")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
REV='\033[7m'
RESET='\033[0m'

# Dynamic width
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
if [ "$TERM_WIDTH" -gt 100 ]; then TERM_WIDTH=100; fi
CONTENT_WIDTH=$((TERM_WIDTH - 4))

# Selection state
SEL_MAIN=0
SEL_MULTI=0

TASK_FILE=""
PIPELINE_ACTIVE=false
PIPELINE_STORY=""
PIPELINE_AGENT=""
PIPELINE_MESSAGE=""
PIPELINE_ITERATION=""
PIPELINE_AGO=""

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
  printf '\033[?25l\033[H\033[2J'
}

finish_draw() {
  printf '\033[J\033[?25h'
}

draw_line() {
  local char="${1:-─}"
  local width="${2:-$CONTENT_WIDTH}"
  local line=""
  for ((i = 0; i < width; i++)); do
    line+="$char"
  done
  echo "$line"
}

read_key() {
  local key
  IFS= read -rsn1 key || { echo "q"; return; }
  if [[ "$key" == $'\x1b' ]]; then
    local seq=""
    IFS= read -rsn2 -t 0.5 seq || true
    case "$seq" in
      '[A') echo "UP"; return ;;
      '[B') echo "DOWN"; return ;;
      '[C') echo "RIGHT"; return ;;
      '[D') echo "LEFT"; return ;;
    esac
    echo "ESC"; return
  elif [[ "$key" == "" ]]; then
    echo "ENTER"; return
  fi
  echo "$key"
}

risk_color() {
  case "$1" in
    low) echo -e "${GREEN}$1${RESET}" ;;
    medium) echo -e "${YELLOW}$1${RESET}" ;;
    high) echo -e "${RED}$1${RESET}" ;;
    *) echo "$1" ;;
  esac
}

get_activity_log_path() {
  local task_basename task_slug
  task_basename=$(basename "$TASK_FILE")
  task_slug="${task_basename#task-}"
  task_slug="${task_slug%.json}"
  echo "$TASK_DIR/activity-$task_slug.log"
}

get_pipeline_status() {
  PIPELINE_ACTIVE=false
  PIPELINE_STORY=""
  PIPELINE_AGENT=""
  PIPELINE_MESSAGE=""
  PIPELINE_ITERATION=""
  PIPELINE_AGO=""

  local activity_log
  activity_log=$(get_activity_log_path)
  [ -f "$activity_log" ] || return 0

  local first_line
  first_line=$(head -1 "$activity_log")
  [ -n "$first_line" ] || return 0

  # Parse iteration from .current-iteration or from log entry
  local iter_file="$SCRIPT_DIR/.current-iteration"
  if [ -f "$iter_file" ]; then
    PIPELINE_ITERATION=$(cat "$iter_file")
  else
    # Extract from log entry: [2025-06-15 12:22:20] [1/10] US-001 ...
    if [[ "$first_line" =~ \[([0-9]+/[0-9]+)\] ]]; then
      PIPELINE_ITERATION="${BASH_REMATCH[1]}"
    fi
  fi

  # Extract story ID and agent from log: [date] [iter] US-XXX agent: message
  if [[ "$first_line" =~ \]\ (US-[0-9]+)\ ([a-z-]+):\ (.*)$ ]]; then
    PIPELINE_STORY="${BASH_REMATCH[1]}"
    PIPELINE_AGENT="${BASH_REMATCH[2]}"
    PIPELINE_MESSAGE="${BASH_REMATCH[3]}"
  fi

  # Extract timestamp and compute age
  if [[ "$first_line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\] ]]; then
    local log_ts="${BASH_REMATCH[1]}"
    local log_epoch now_epoch diff_secs
    log_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$log_ts" "+%s" 2>/dev/null) || return 0
    now_epoch=$(date "+%s")
    diff_secs=$((now_epoch - log_epoch))

    if [ "$diff_secs" -lt 300 ]; then
      PIPELINE_ACTIVE=true
    fi

    if [ "$diff_secs" -lt 60 ]; then
      PIPELINE_AGO="${diff_secs}s ago"
    elif [ "$diff_secs" -lt 3600 ]; then
      PIPELINE_AGO="$((diff_secs / 60))m ago"
    elif [ "$diff_secs" -lt 86400 ]; then
      PIPELINE_AGO="$((diff_secs / 3600))h ago"
    else
      PIPELINE_AGO="$((diff_secs / 86400))d ago"
    fi
  fi
}

draw_status_bar() {
  [ -n "$PIPELINE_STORY" ] || return 0

  local indicator
  if [ "$PIPELINE_ACTIVE" = true ]; then
    indicator="${GREEN}●${RESET} ${GREEN}ACTIVE${RESET}"
  else
    indicator="${DIM}○ IDLE${RESET}"
  fi

  local iter_str=""
  if [ -n "$PIPELINE_ITERATION" ]; then
    iter_str="  Iteration ${BOLD}${PIPELINE_ITERATION}${RESET}"
  fi

  local detail=""
  if [ -n "$PIPELINE_STORY" ] && [ -n "$PIPELINE_AGENT" ]; then
    detail="  ${PIPELINE_STORY} ${PIPELINE_AGENT}: ${PIPELINE_MESSAGE}"
  fi

  local ago_str=""
  if [ -n "$PIPELINE_AGO" ]; then
    ago_str="  ${DIM}${PIPELINE_AGO}${RESET}"
  fi

  printf "  %b%b%b%b\n" "$indicator" "$iter_str" "$detail" "$ago_str"
  echo ""
}

draw_progress_bar() {
  local passing=$1
  local total=$2
  local bar_width=20

  local filled=0
  if [ "$total" -gt 0 ]; then
    filled=$((passing * bar_width / total))
  fi
  local empty=$((bar_width - filled))

  local color
  if [ "$passing" -eq "$total" ]; then
    color="$GREEN"
  elif [ "$passing" -gt 0 ]; then
    color="$YELLOW"
  else
    color="$RED"
  fi

  local bar="${color}"
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  bar+="${RESET}"

  printf "  [%b] %s/%s\n" "$bar" "$passing" "$total"
}

draw_activity_feed() {
  local activity_log
  activity_log=$(get_activity_log_path)
  [ -f "$activity_log" ] || return 0

  local lines
  lines=$(head -3 "$activity_log")
  [ -n "$lines" ] || return 0

  echo ""
  printf "  ${BOLD}Recent Activity${RESET}\n"

  while IFS= read -r entry; do
    # Strip date portion, keep just time: [2025-06-15 12:22:20] -> 12:22:20
    local display
    display=$(echo "$entry" | sed 's/^\[[0-9]*-[0-9]*-[0-9]* //')
    display="${display#[}"
    # Now display looks like: 12:22:20] [1/10] US-001 ...
    # Remove the closing bracket after time
    display=$(echo "$display" | sed 's/^\([0-9:]*\)] /\1  /')
    printf "  ${DIM}%s${RESET}\n" "$display"
  done <<< "$lines"
}

show_overview() {
  clear_screen

  get_pipeline_status

  local filename
  filename=$(basename "$TASK_FILE")
  local total
  total=$(jq '.userStories | length' "$TASK_FILE")
  local passing
  passing=$(jq '[.userStories[] | select(.passes == true)] | length' "$TASK_FILE")
  local pct=0
  if [ "$total" -gt 0 ]; then
    pct=$((passing * 100 / total))
  fi

  # Clamp selection
  if [ "$total" -gt 0 ]; then
    if [ "$SEL_MAIN" -ge "$total" ]; then
      SEL_MAIN=$((total - 1))
    fi
  else
    SEL_MAIN=0
  fi

  local title_width=$((CONTENT_WIDTH - 22))

  draw_status_bar

  echo ""
  printf "  ${BOLD}"
  draw_line "═"
  printf "${RESET}"
  echo ""
  printf "  ${BOLD}%s${RESET}  ${DIM}v%s${RESET}\n" "$filename" "$VERSION"
  printf "  ${GREEN}%s${RESET}/${BOLD}%s${RESET} stories passing  (%s%%)\n" "$passing" "$total" "$pct"
  draw_progress_bar "$passing" "$total"
  printf "  ${BOLD}"
  draw_line "═"
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

    # Truncate title if needed
    if [ "${#title}" -gt "$title_width" ]; then
      title="${title:0:$((title_width - 1))}~"
    fi

    if [ "$i" -eq "$SEL_MAIN" ]; then
      local plain_bullet
      if [ "$passes" = "true" ]; then plain_bullet="*"; else plain_bullet="o"; fi
      printf "  ${REV} %s %-7s %-${title_width}s ${RESET}\n" "$plain_bullet" "$id" "$title"
    else
      local bullet
      if [ "$passes" = "true" ]; then
        bullet="${GREEN}●${RESET}"
      elif [ "$PIPELINE_ACTIVE" = true ] && [ "$PIPELINE_STORY" = "$id" ]; then
        bullet="${YELLOW}●${RESET}"
      else
        bullet="${DIM}○${RESET}"
      fi

      local risk_str=""
      if [ -n "$risk" ]; then
        risk_str=" [$(risk_color "$risk")]"
      fi

      printf "  %b %-7s %-${title_width}s%b\n" "$bullet" "$id" "$title" "$risk_str"
    fi

    i=$((i + 1))
  done < <(jq -c '.userStories[]' "$TASK_FILE")

  draw_activity_feed

  echo ""
  printf "  ${DIM}"
  draw_line
  printf "${RESET}"
  echo ""
  if [ "$(task_count)" -gt 1 ]; then
    printf "  j/k navigate  l/Enter open  t toggle  g log  h/Esc back  q quit\n"
  else
    printf "  j/k navigate  l/Enter open  t toggle  g log  q quit\n"
  fi
  echo ""
  finish_draw
}

show_log() {
  clear_screen

  local task_basename activity_log
  task_basename=$(basename "$TASK_FILE")
  activity_log=$(get_activity_log_path)

  echo ""
  printf "  ${BOLD}Activity Log${RESET} ${DIM}($task_basename)${RESET}\n"
  printf "  ${BOLD}"
  draw_line
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
  draw_line
  printf "${RESET}"
  echo ""
  printf "  h/Esc back  r refresh\n"
  echo ""
  finish_draw
}

log_loop() {
  while true; do
    show_log
    local key
    key=$(read_key)
    case "$key" in
      h|H|b|B|ESC) return ;;
      r|R) continue ;;
      q|Q) exit 0 ;;
    esac
  done
}

show_multi_task_overview() {
  clear_screen

  echo ""
  printf "  ${BOLD}"
  draw_line "═"
  printf "${RESET}"
  echo ""
  printf "  ${BOLD}All Tasks${RESET}  ${DIM}v%s${RESET}\n" "$VERSION"
  printf "  ${BOLD}"
  draw_line "═"
  printf "${RESET}"
  echo ""
  echo ""

  # Build task list
  TASK_LIST=()
  while IFS= read -r task_name; do
    TASK_LIST+=("$task_name")
  done < <(list_tasks)

  # Clamp selection
  if [ "${#TASK_LIST[@]}" -gt 0 ]; then
    if [ "$SEL_MULTI" -ge "${#TASK_LIST[@]}" ]; then
      SEL_MULTI=$((${#TASK_LIST[@]} - 1))
    fi
  fi

  # Render task list
  local i=0
  for task_name in "${TASK_LIST[@]}"; do
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

    if [ "$i" -eq "$SEL_MULTI" ]; then
      printf "  ${REV} %-30s  %s/%s passing ${RESET}\n" "$task_name" "$passing" "$total"
    else
      printf "   %-30s  %b%s/%s passing${RESET}\n" "$task_name" "$color" "$passing" "$total"
    fi
    i=$((i + 1))
  done

  if [ "${#TASK_LIST[@]}" -eq 0 ]; then
    printf "  ${DIM}No tasks found${RESET}\n"
  fi

  echo ""
  printf "  ${DIM}"
  draw_line
  printf "${RESET}"
  echo ""
  printf "  j/k navigate  l/Enter open  r refresh  q quit\n"
  echo ""
  finish_draw
}

multi_task_loop() {
  while true; do
    show_multi_task_overview
    local key
    key=$(read_key)
    case "$key" in
      j|J)
        if [ "$SEL_MULTI" -lt "$((${#TASK_LIST[@]} - 1))" ]; then
          SEL_MULTI=$((SEL_MULTI + 1))
        fi
        ;;
      k|K)
        if [ "$SEL_MULTI" -gt 0 ]; then
          SEL_MULTI=$((SEL_MULTI - 1))
        fi
        ;;
      l|L|ENTER)
        if [ "${#TASK_LIST[@]}" -gt 0 ]; then
          TASK_FILE="$TASK_DIR/${TASK_LIST[$SEL_MULTI]}"
          main_loop
        fi
        ;;
      r|R) continue ;;
      q|Q) exit 0 ;;
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
  draw_line
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
    echo "$description" | fold -s -w $((CONTENT_WIDTH - 4)) | while IFS= read -r line; do
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
  draw_line
  printf "${RESET}"
  echo ""
  printf "  h/Esc back  t toggle  n edit notes  q quit\n"
  echo ""
  finish_draw
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
    local key
    key=$(read_key)
    case "$key" in
      h|H|b|B|ESC) return ;;
      t|T) toggle_pass "$index" ;;
      n|N) edit_notes "$index" ;;
      q|Q) exit 0 ;;
    esac
  done
}

main_loop() {
  while true; do
    show_overview
    local total
    total=$(jq '.userStories | length' "$TASK_FILE")
    local key
    key=$(read_key)
    case "$key" in
      j|J)
        if [ "$SEL_MAIN" -lt "$((total - 1))" ]; then
          SEL_MAIN=$((SEL_MAIN + 1))
        fi
        ;;
      k|K)
        if [ "$SEL_MAIN" -gt 0 ]; then
          SEL_MAIN=$((SEL_MAIN - 1))
        fi
        ;;
      l|L|ENTER)
        if [ "$total" -gt 0 ]; then
          story_detail_loop "$SEL_MAIN"
        fi
        ;;
      t|T)
        if [ "$total" -gt 0 ]; then
          toggle_pass "$SEL_MAIN"
        fi
        ;;
      g|G) log_loop ;;
      h|H|ESC)
        if [ "$(task_count)" -gt 1 ]; then
          return
        fi
        ;;
      r|R) continue ;;
      q|Q) exit 0 ;;
    esac
  done
}

# --- Entry point ---

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

trap 'printf "\033[?25h"' EXIT

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
