# Ralph+ Cheat Sheet

## Quick Start

```bash
# Initialize architecture (once per project)
claude 'Use the architect agent to initialize this project'

# Create a task - strategist researches your codebase and asks you questions
claude 'Use the strategist agent to plan [describe your feature]'

# Run it - each story goes through planner -> tdd -> quality-gate -> committer
./ralph-plus/run-task-loop.sh --task task-<name>.json
```

## Dashboard

```bash
./ralph-plus/dashboard.sh                    # auto-loads if single task
./ralph-plus/dashboard.sh task-<name>.json   # specific task
```

## Agents

| Agent        | What it does                        | When to use directly            |
| ------------ | ----------------------------------- | ------------------------------- |
| architect    | Sets up architecture + quality gates | Once per project, or on big changes |
| strategist   | Breaks feature into stories         | Starting any new feature        |
| planner      | Plans implementation for one story  | (run-task-loop handles this)    |
| tdd          | Red-Green-Refactor                  | (run-task-loop handles this)    |
| e2e          | Playwright acceptance tests         | (run-task-loop handles this)    |
| quality-gate | Lint, typecheck, format, tests      | (run-task-loop handles this)    |
| committer    | Git commit + progress tracking      | (run-task-loop handles this)    |

## Files

| Path                          | What it is                          |
| ----------------------------- | ----------------------------------- |
| `docs/architecture.md`        | Project architecture + quality gates |
| `docs/tasks/task-<name>.json` | Stories with pass/fail status       |
| `docs/tasks/progress-<name>.txt` | Learnings log from each story    |
| `.claude/agents/`             | Agent definitions                   |
| `.mcp.json`                   | MCP server config                   |
