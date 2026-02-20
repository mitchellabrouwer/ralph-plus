# Ralph+ Orchestrator

You coordinate a multi-agent pipeline. One user story per iteration.

## Startup

1. Read `ralph-plus/.current-task` -> get task file path -> read task file
2. Read `ralph-plus/.current-progress` -> get progress log path -> read it
3. Read `ralph-plus/.current-activity-log` -> get activity log path
4. Read `ralph-plus/.current-iteration` -> get iteration (e.g. `3/10`)
5. Read `docs/tasks/LEARNINGS.md` if it exists (accumulated patterns from past tasks)
6. If task or progress file missing, stop and ask user to run with `--task`
7. Check correct branch (task file `branchName`). Create from main if needed.
8. Pick highest priority story where `passes: false`
9. Run the pipeline below
10. If ALL stories `passes: true`, run the **Archive** step below then reply `<promise>COMPLETE</promise>`

No story with `passes: false`? Run the **Archive** step below then reply `<promise>COMPLETE</promise>` and stop.

## Pipeline

Run agents **sequentially** via Task tool. Pass each agent's output to the next.

### Context to pass to every agent

Include these lines at the top of every agent Task prompt:

- Activity log: <path from `.current-activity-log`>
- Iteration: <value from `.current-iteration`>
- Story: <current story ID>

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

If quality-gate fails, mark the story failed: add failure details to story `notes`, do NOT set `passes: true`.

Log `orchestrator: ITERATION_FAIL - <reason>` to the activity log as the very last action.

No retries. The quality gate already attempted mechanical fixes internally. If it still fails, the issue needs human attention.

## On BLOCKED

If quality-gate reports **BLOCKED**, the environment/tooling is broken and no further stories can pass until it's fixed. **Stop the entire pipeline immediately.** Do NOT move to the next story (it will hit the same problem).

Log `orchestrator: ITERATION_BLOCKED - <reason from quality-gate>` to the activity log as the very last action, then output a clear message to the user stating exactly what needs to be fixed before the pipeline can resume.

## After Committer

Re-read task file. All `passes: true`? Run the **Archive** step then output `<promise>COMPLETE</promise>`. Otherwise log `orchestrator: ITERATION_DONE` to the activity log as the very last action.

## Archive

Run this when all stories pass, before outputting `<promise>COMPLETE</promise>`.

1. Read the progress file's `## Codebase Patterns` section
2. Append it to `docs/tasks/LEARNINGS.md` under a heading with the task name and date:
   ```
   ## task-slug-name (YYYY-MM-DD)
   <patterns from progress file>
   ```
   If `LEARNINGS.md` doesn't exist, create it with a `# Codebase Learnings` title first.
3. Create `docs/tasks/completed/` if it doesn't exist
4. Move this task's specific files into it: `task-<slug>.json`, `prd-<slug>.md`, `progress-<slug>.txt`, `activity-<slug>.log`
5. Log the archive to the activity log before moving it: `orchestrator: archived task to completed/`
6. Commit the archive (learnings update + moved files) with message: `chore: archive completed task <slug>`
7. Log `orchestrator: ITERATION_DONE` to the activity log as the very last action (before outputting `<promise>COMPLETE</promise>`)

## Activity Log

Append one-line entries to the activity log at each step:

Prepend (newest first) one-line entries using this pattern:

```bash
tmp=$(mktemp) && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [3/10] US-XXX agent: message"; cat /path/to/activity-log; } > "$tmp" && mv "$tmp" /path/to/activity-log
```

Include the iteration from `.current-iteration` and the current story ID in every log entry.

Events: `orchestrator: picked US-XXX (Title)` | `planner: starting` / `planner: done - N files, N steps` | `tdd: starting` / `tdd: done - N tests passing` | `quality-gate: PASS` or `FAIL - reason` or `BLOCKED - reason` | `committer: done` | `orchestrator: ITERATION_DONE` | `orchestrator: ITERATION_FAIL - reason` | `orchestrator: ITERATION_BLOCKED - reason`

## Rules

- One story per iteration, agents sequential
- Pass context via Task tool prompts, no temp files
- Never modify code yourself
- Read Codebase Patterns from both `docs/tasks/LEARNINGS.md` and the current progress log before starting
- Always log an ITERATION signal (`ITERATION_DONE`, `ITERATION_FAIL`, or `ITERATION_BLOCKED`) as the very last action of every iteration
