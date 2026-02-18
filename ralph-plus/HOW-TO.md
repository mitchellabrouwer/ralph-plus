# Ralph+ Cheat Sheet

## Quick Start

```bash
# Product discovery (once per project) - defines problem, market, scope
claude 'Use the product agent to define this project'

# Initialize architecture (once per project)
claude 'Use the architect agent to initialize this project'

# Create a task - strategist researches your codebase and asks you questions
claude 'Use the strategist agent to plan [describe your feature]'

# Run it - each story goes through planner -> tdd -> quality-gate -> committer
./ralph-plus/run-monitored.sh --task task-<name>.json        # tmux session (recommended)
./ralph-plus/run-unmonitored.sh --task task-<name>.json      # direct, no tmux
./ralph-plus/run-unmonitored.sh --task task-<name>.json 5    # custom iteration limit
```

Each iteration handles one story. Default is 10 iterations (so up to 10 stories per run).

## Dashboard

```bash
./ralph-plus/dashboard.sh                    # auto-loads if single task
./ralph-plus/dashboard.sh task-<name>.json   # specific task
```

## Agents

| Agent        | What it does                        | When to use directly            |
| ------------ | ----------------------------------- | ------------------------------- |
| product    | Product discovery: problem, market, scope | Once per project, before architect |
| architect    | Sets up architecture + quality gates | Once per project, or on big changes |
| strategist   | Breaks feature into stories         | Starting any new feature        |
| planner      | Plans implementation for one story  | (pipeline handles this)         |
| tdd          | Red-Green-Refactor                  | (pipeline handles this)         |
| e2e          | Playwright acceptance tests         | (pipeline handles this)         |
| quality-gate | Lint, typecheck, format, tests, complexity, security | (pipeline handles this)         |
| committer    | Git commit + progress tracking      | (pipeline handles this)         |
| verify       | Manual feature verification via Playwright | `Use the verify agent to check task-<name>.json at http://localhost:3000` |

## Files

| Path                          | What it is                          |
| ----------------------------- | ----------------------------------- |
| `docs/product.md`             | Product discovery: problem, market, scope |
| `docs/architecture.md`        | Project architecture + quality gates |
| `docs/tasks/task-<name>.json` | Stories with pass/fail status       |
| `docs/tasks/progress-<name>.txt` | Learnings log from each story    |
| `.claude/agents/`             | Agent definitions                   |
| `.mcp.json`                   | MCP server config                   |
