# PRD: Pipeline Observability and Dashboard Fixes

## Introduction/Overview

When a Ralph+ agent runs (especially TDD or E2E, which can take 10-20 minutes), there is zero visibility into what is happening. The activity log only updates at agent boundaries ("starting" / "done"), so the dashboard has nothing new to show during long runs.

This feature adds two things: (1) heartbeat logging, where each agent periodically writes progress lines to the existing activity log during execution, and (2) auto-refresh in the dashboard log view so users see those heartbeat lines without manually pressing `r`. A small proof-of-concept test validates the approach before rolling it out to all agents. Separately, arrow key handling is removed from the dashboard to fix navigation issues.

## Goals

- Give users real-time visibility into agent progress during long-running pipeline iterations
- Validate the heartbeat logging approach with a minimal proof-of-concept before full rollout
- Add auto-refresh to the dashboard activity log view so new heartbeat lines appear automatically
- Remove arrow key handling from the dashboard to fix navigation bugs
- Keep changes minimal: no new files, no new dependencies, no architectural changes

## User Stories

### US-001: Remove arrow key handling from dashboard

**Description:** As a user, I want only j/k/h/l keys to navigate the dashboard so that arrow keys no longer cause display issues.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**

- [ ] Arrow key cases (UP, DOWN, LEFT, RIGHT) are removed from `main_loop`, `multi_task_loop`, `story_detail_loop`, and `log_loop` in `ralph-plus/dashboard.sh`
- [ ] The `read_key` function still reads escape sequences (so they do not produce garbage output) but the returned values are simply not matched by any case branch
- [ ] Help text at the bottom of every screen no longer references "arrows" - only shows j/k/h/l/Enter
- [ ] Help text in `show_multi_task_overview` no longer references "arrows"
- [ ] All existing j/k/h/l/Enter navigation continues to work unchanged
- [ ] Shellcheck clean on `ralph-plus/dashboard.sh`

### US-002: Add auto-refresh to dashboard activity log view

**Description:** As a user, I want the activity log view to auto-refresh every few seconds so that I can watch agent progress without repeatedly pressing `r`.
**Risk:** medium
**Test Requirements:** unit, integration

**Acceptance Criteria:**

- [ ] The `log_loop` function in `ralph-plus/dashboard.sh` uses a `read -t 3` timeout (3-second cycle) instead of a blocking `read` so the view re-renders automatically
- [ ] The `read_key` function is NOT modified; instead, `log_loop` uses its own read with timeout, falling through to re-render `show_log` when the timeout expires
- [ ] Manual key handling still works: `h`/Esc returns to overview, `q` quits, `r` forces immediate refresh
- [ ] The log view header shows a visual indicator that auto-refresh is active (e.g., a small "auto" label or a refresh symbol)
- [ ] The `show_log` function reads up to 30 lines from the activity log (currently 20) to show more heartbeat context
- [ ] Shellcheck clean on `ralph-plus/dashboard.sh`

### US-003: Validate heartbeat logging with a proof-of-concept test

**Description:** As a developer, I want to verify that a Task tool subagent can write heartbeat lines to the activity log during execution so that we know the approach works before rolling it out to all agents.
**Risk:** medium
**Test Requirements:** unit, integration

**Acceptance Criteria:**

- [ ] A test script exists at `ralph-plus/test-heartbeat.sh` that: (a) creates a temporary activity log file, (b) invokes `claude --print` with a prompt that includes the Bash tool and instructions to prepend 3 heartbeat lines to the activity log using the documented prepend pattern, (c) verifies the activity log contains the expected heartbeat lines after the session completes
- [ ] The test script uses the same prepend pattern documented in `ralph-plus/CLAUDE.md`: `tmp=$(mktemp) && { echo "[timestamp] [iter] story-id agent: message"; cat logfile; } > "$tmp" && mv "$tmp" logfile`
- [ ] The test script outputs PASS or FAIL with details
- [ ] The test script is self-contained and can be run independently: `./ralph-plus/test-heartbeat.sh`
- [ ] Shellcheck clean on `ralph-plus/test-heartbeat.sh`

### US-004: Add heartbeat logging instructions to all agent definitions

**Description:** As a user, I want each pipeline agent to periodically log progress lines to the activity log so that I can see what is happening during long-running agent executions.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**

- [ ] Each agent definition (`agents/planner.md`, `agents/tdd.md`, `agents/e2e.md`, `agents/quality-gate.md`, `agents/committer.md`) has a new "Heartbeat Logging" section
- [ ] The section instructs the agent to prepend progress lines to the activity log at meaningful milestones (not on a timer, but at logical progress points)
- [ ] The section specifies the exact prepend pattern: `tmp=$(mktemp) && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ITERATION] STORY_ID AGENT_NAME: message"; cat ACTIVITY_LOG_PATH; } > "$tmp" && mv "$tmp" ACTIVITY_LOG_PATH`
- [ ] The section tells agents they will receive `ACTIVITY_LOG_PATH`, `ITERATION`, and `STORY_ID` in their Task prompt from the orchestrator
- [ ] Example heartbeat messages are provided per agent: planner ("analyzing codebase", "looking up docs", "plan complete"), tdd ("writing tests for X", "N/M tests passing", "refactoring"), e2e ("setting up browser", "testing criterion N"), quality-gate ("running typecheck", "running lint", "running tests"), committer ("staging files", "committing")
- [ ] The instructions are concise (no more than 15-20 lines per agent)
- [ ] Shellcheck clean is not applicable (markdown files), but the bash snippet in the instructions is correct

### US-005: Update orchestrator to pass heartbeat context to agents

**Description:** As a pipeline orchestrator, I want to include the activity log path, iteration number, and story ID in every Task prompt so that agents can write heartbeat lines.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**

- [ ] `ralph-plus/CLAUDE.md` is updated so the orchestrator's Pipeline section instructs it to include three values in every agent Task prompt: the activity log path (from `.current-activity-log`), the current iteration (from `.current-iteration`), and the current story ID
- [ ] The instruction is added once in a general "Context to pass to every agent" subsection, not repeated per agent
- [ ] The format is explicit: "Include these lines at the top of every agent prompt: Activity log: <path>, Iteration: <iteration>, Story: <story-id>"
- [ ] Existing agent prompt instructions in the Pipeline section are not otherwise changed
- [ ] Shellcheck clean is not applicable (markdown file)

## Functional Requirements

- FR-1: The dashboard must not respond to arrow key input (UP, DOWN, LEFT, RIGHT) in any view
- FR-2: Help text on all dashboard screens must reference only j/k/h/l/Enter, not arrows
- FR-3: The activity log view must auto-refresh on a 3-second cycle without requiring user input
- FR-4: A proof-of-concept test must validate that a `claude --print` session with Bash access can prepend lines to an external log file using the documented pattern
- FR-5: All five agent definitions must include a Heartbeat Logging section with the prepend pattern and agent-specific example messages
- FR-6: The orchestrator prompt must instruct passing activity log path, iteration, and story ID to every agent

## Non-Goals

- No separate per-agent log files - all heartbeats go to the single existing activity log
- No new dashboard views or screens - the existing log view gets auto-refresh
- No timer-based heartbeats inside agents - agents log at logical milestones
- No changes to the Task tool architecture or how agents are spawned
- No changes to `run-task-loop.sh` beyond what is strictly needed
- No live-tailing of claude stdout to a separate file (the activity log approach replaces this)

## Design Considerations

- The `read_key` function in `dashboard.sh` should continue to consume escape sequences silently (to prevent raw escape characters from appearing on screen) but the returned UP/DOWN/LEFT/RIGHT values simply fall through unmatched in `case` statements
- Auto-refresh in `log_loop` should use `read -rsn1 -t 3 key` directly rather than calling `read_key`, because `read_key` blocks indefinitely. On timeout, the loop re-renders. On keypress, handle it normally.
- Agent heartbeat instructions should be short and practical. Agents are already long prompts; add the minimum needed.

## Technical Considerations

- The prepend pattern (`mktemp` + `cat` + `mv`) is already documented and used by the orchestrator. Agents will use the identical pattern.
- The activity log path is already written to `ralph-plus/.current-activity-log` by `run-task-loop.sh`. The orchestrator reads this at startup. The orchestrator just needs to pass it through to agents in their Task prompts.
- Auto-refresh uses `read -rsn1 -t N` which returns exit code 142 (or >128) on timeout. The `log_loop` function should treat timeout as "re-render" and keypress as "handle key."
- Heartbeat lines follow the existing log format: `[YYYY-MM-DD HH:MM:SS] [iter/max] US-XXX agent-name: message`

## Success Metrics

- During a pipeline run, the activity log receives 3-8 heartbeat lines per agent execution (not just "starting"/"done")
- The dashboard log view updates automatically every 3 seconds, showing new heartbeat lines without user intervention
- Arrow keys produce no effect in the dashboard (no display glitches, no navigation)
- The proof-of-concept test passes, confirming agents can write to the activity log

## Open Questions

- None. The proof-of-concept test (US-003) will answer whether the heartbeat approach works reliably before US-004 and US-005 roll it out.
