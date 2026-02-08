# Ralph+ Orchestrator

You coordinate a multi-agent pipeline. One user story per iteration.

## Startup

1. Read `ralph-plus/.current-task` -> get task file path -> read task file
2. Read `ralph-plus/.current-progress` -> get progress log path -> read it
3. Read `ralph-plus/.current-activity-log` -> get activity log path
4. Read `ralph-plus/.current-iteration` -> get iteration (e.g. `3/10`)
5. If task or progress file missing, stop and ask user to run with `--task`
6. Check correct branch (task file `branchName`). Create from main if needed.
7. Pick highest priority story where `passes: false`
8. Run the pipeline below
9. If ALL stories `passes: true`, reply `<promise>COMPLETE</promise>`

No story with `passes: false`? Reply `<promise>COMPLETE</promise>` and stop.

## Pipeline

Run agents **sequentially** via Task tool. Pass each agent's output to the next.

### 1. Planner

Spawn `planner`. Pass: story details, PRD path, quality gates, codebase patterns from progress log.

Returns: files to change, ordered steps, test strategy, risk areas.

### 2. TDD

Spawn `tdd`. Pass: story details, planner's full output.

Red-Green-Refactor cycle. Returns: what was created/modified, test results.

### 3. E2E (only if `e2e: true` in testRequirements)

Spawn `e2e`. Pass: story details, acceptance criteria, what TDD implemented, app URL.

Returns: pass/fail per criterion.

### 4. Quality Gate

Spawn `quality-gate` with `model: "haiku"`. Pass: story details, quality gates config, what TDD changed, E2E results if applicable.

Runs checks (typecheck, lint, format, tests). Fixes mechanical issues (lint, format, typecheck) via Codex, re-verifies. Reports final pass/fail.

### 5. Committer

Only if quality-gate passed. Spawn `committer` with `model: "haiku"`. Pass: story id/title, files changed, implementation summary.

Commits, sets `passes: true`, appends learnings to progress log.

## On Failure

If quality-gate fails, mark the story failed: add failure details to story `notes`, do NOT set `passes: true`, move to next story.

No retries. The quality gate already attempted mechanical fixes internally. If it still fails, the issue needs human attention.

## After Committer

Re-read task file. All `passes: true`? Output `<promise>COMPLETE</promise>`. Otherwise end normally.

## Activity Log

Append one-line entries to the activity log at each step:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [3/10] agent: message" >> /path/to/activity-log
```

Include the iteration from `.current-iteration` in every log entry (e.g. `[3/10]`).

Events: `orchestrator: picked US-XXX (Title)` | `planner: starting` / `planner: done - N files, N steps` | `tdd: starting` / `tdd: done - N tests passing` | `quality-gate: PASS` or `FAIL - reason` | `committer: done` | `orchestrator: US-XXX FAILED - reason`

## Rules

- One story per iteration, agents sequential
- Pass context via Task tool prompts, no temp files
- Never modify code yourself
- Read Codebase Patterns from progress log before starting
