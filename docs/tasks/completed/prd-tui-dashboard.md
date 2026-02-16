# PRD: TUI Dashboard Upgrade

## Introduction

Upgrade the existing `scripts/dashboard.sh` bash TUI to support three new capabilities: a multi-task overview showing all task files with aggregate pass/fail stats, a progress log viewer for reading `progress-*.txt` files inline, and a live pipeline view that tails the running `run-task-loop.sh` output to show which agent is active. The dashboard stays pure bash + jq with ANSI escape codes. No external TUI frameworks.

## Goals

- Show aggregate status across all `task-*.json` files in a single view
- Let users read and scroll through progress logs without leaving the dashboard
- Display live pipeline activity when `run-task-loop.sh` is running
- Preserve all existing dashboard functionality (story list, detail view, toggle, notes)
- Keep the implementation simple: bash, jq, ANSI codes, no new dependencies

## User Stories

### US-001: Multi-task overview screen
**Description:** As a user, I want to see all task files with their pass/fail counts on one screen so that I can quickly assess project-wide progress.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] New screen lists every `task-*.json` in `docs/tasks/` with filename, passing count, and total story count
- [ ] Each task row shows a summary like `task-auth.json  3/5 passing`
- [ ] Color coding: all-green if fully passing, yellow if partial, red if zero passing
- [ ] User can select a task by number to enter the existing story overview for that task
- [ ] This screen is the new default landing screen when multiple task files exist (replaces the old selection prompt)
- [ ] Accessible from the story overview via `[a]` (all tasks) command to return to it
- [ ] Typecheck passes (shellcheck clean)
- [ ] Manual verification: running `./scripts/dashboard.sh` shows the new screen

### US-002: Progress log viewer
**Description:** As a user, I want to view the progress log for the current task inside the dashboard so that I can review what the pipeline has done without switching terminals.
**Risk:** medium
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] New `[p]` command from the story overview opens the progress log viewer
- [ ] Viewer shows the content of `progress-<task-slug>.txt` corresponding to the loaded task
- [ ] Content is paginated: shows 30 lines at a time with `[n]` next / `[b]` back navigation
- [ ] Displays line numbers in the left margin
- [ ] `[/]` command enters search mode: user types a pattern, viewer highlights and jumps to matching lines (e.g., `/FAIL` finds failure entries)
- [ ] Search results navigable with `[n]` next match / `[N]` previous match
- [ ] If no progress file exists, shows a "No progress log found" message
- [ ] `[q]` or `[esc]` returns to the story overview
- [ ] Typecheck passes (shellcheck clean)

### US-003: Live pipeline status indicator
**Description:** As a user, I want to see whether the pipeline is currently running and which iteration it is on, so I know if work is in progress.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Dashboard header shows a status indicator: `RUNNING (iteration 3/10)` or `IDLE`
- [ ] Detection works by checking if a `run-task-loop.sh` process is alive (via `pgrep` or checking `.current-task` freshness)
- [ ] If running, parse the most recent iteration number from the pipeline output or progress log
- [ ] Status refreshes each time the user returns to the overview screen (on `[r]` refresh)
- [ ] Indicator uses color: green pulsing dot for running, dim gray for idle
- [ ] Typecheck passes (shellcheck clean)

### US-004: Keyboard navigation improvements
**Description:** As a user, I want consistent keyboard shortcuts and a help bar across all screens so the dashboard feels cohesive.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Every screen shows a bottom command bar with available shortcuts
- [ ] `[?]` on any screen shows a full help overlay listing all commands
- [ ] `[q]` always quits from any screen
- [ ] `[r]` refreshes data on any list screen (overview, multi-task, log viewer)
- [ ] Help overlay dismissed with any keypress
- [ ] Typecheck passes (shellcheck clean)

## Functional Requirements

- FR-1: Add a multi-task overview screen that lists all `task-*.json` files with pass/fail summary stats; this becomes the default landing screen when multiple tasks exist
- FR-2: Add a progress log viewer that paginates `progress-<slug>.txt` content with line numbers and supports `grep`-style search with match navigation
- FR-3: Add a pipeline status indicator in the dashboard header showing running/idle state and current iteration
- FR-4: Add a `[?]` help overlay accessible from every screen
- FR-5: Maintain backwards compatibility with existing CLI arguments (`--list`, explicit task file, auto-load single task)
- FR-6: All new code must pass `shellcheck` with no errors

## Non-Goals

- No real-time auto-refresh or watch mode (user triggers refresh manually)
- No editing of progress logs from the dashboard
- No web-based or GUI interface
- No dependency on ncurses, dialog, whiptail, or any external TUI library
- No rewrite of the core story detail or toggle functionality

## Technical Considerations

- The existing `dashboard.sh` is ~374 lines of bash. New features add to it in-place.
- `jq` is the only external dependency (already required).
- `pgrep` is available on macOS and Linux for process detection.
- Progress files follow the naming convention `progress-<slug>.txt` where slug matches the task file name.
- Pipeline detection can check for `run-task-loop.sh` in the process list or check `.current-task` / `.current-progress` sentinel files.
- Screen rendering uses `printf` with ANSI escape codes, same as the existing code.
- Pagination state (current page, total pages) can be tracked with simple bash variables.

## Success Metrics

- User can see all task files and their status in one glance from the multi-task screen
- User can read the full progress log without leaving the dashboard
- User can tell at a glance whether the pipeline is running or idle
- All existing functionality (story list, detail, toggle, notes) continues to work unchanged

## Open Questions

None.
