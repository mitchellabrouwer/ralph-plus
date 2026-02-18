# Ralph+ ⛳

A multi-agent pipeline for autonomous feature implementation using TDD.

## Quick Start

```bash
# 1. Setup - copy agents and ralph-plus into your project
path/to/ralph-plus/setup.sh /path/to/your-project

# 2. Initialize architecture (once per project)
claude 'Use the architect agent to initialize this project'

# 3. Create a task - strategist researches your codebase and asks you questions
claude 'Use the strategist agent to plan [describe your feature]'

# 4. Run it - each story goes through planner -> tdd -> quality-gate -> committer
./ralph-plus/run-monitored.sh --task task-<name>.json
```

You focus on step 3 (describing the feature, answering questions, reviewing stories). Everything after that is autonomous.

## Concepts

Think of Ralph+ like a golf team.

**🏌️ Players (Agents)** - Each player has a specific role on the team. The strategist reads the course. The planner picks the shot. The tdd player executes. They know their job, but they don't all need the same equipment or training.

**🏑 Clubs (MCPs)** - Different clubs for different shots. You wouldn't putt with a driver. Each player's bag only has the clubs they need. The strategist carries research clubs (Codex, Gemini, Context7). The e2e player carries the Playwright set. The quality-gate carries nothing - it just reads the scorecard.

|     | Concept  | Directory   | What it is                                    |
| --- | -------- | ----------- | --------------------------------------------- |
| 🏌️  | Players  | `agents/`   | Agent definitions - who does what             |
| 🏑  | Clubs    | `.mcp.json` | External tools (AI models, browser, docs)     |

> **Note:** This project favors agents over skills. Agents allow finer control - you can specify the model (opus, sonnet, haiku) and exactly which MCP tools each agent has access to. Skills don't have this level of configuration.

## The Team

| 🏌️ Player    | Role                                        | 🧠 Model (Brain) | 🏑 Clubs (MCPs)         |
| ------------ | ------------------------------------------- | ---------------- | ----------------------- |
| architect    | Sets project architecture and quality gates | opus             | codex, gemini, context7 |
| strategist   | Reads the course, plans the round           | opus             | codex, gemini, context7 |
| planner      | Plans each shot                             | opus             | codex, gemini, context7 |
| tdd          | Executes the shots                          | opus             | codex, context7         |
| e2e          | Checks the ball landed where expected       | sonnet           | playwright, context7    |
| quality-gate | Rules official, checks the scorecard        | haiku            | -                       |
| committer    | Records the score                           | haiku            | -                       |
| verify       | Manual feature verification                 | sonnet           | playwright, context7    |

## How It Works

You handle strategy. The agents handle everything else.

```
 YOU                          AGENTS (autonomous)
  │                               │
  │  1. Describe feature          │
  │  2. Answer questions ◄────►  strategist (researches, asks, produces task-<name>.json)
  │  3. Architect           ◄──  (if first time or feature outside current arch)
  │  4. Review task-<name>.json         │
  │  5. Run run-monitored.sh            │
  │                               │
  │                          per story:
  │                               ├── planner       (technical plan)
  │                               ├── tdd           (Red-Green-Refactor)
  │                               ├── e2e           (Playwright, high-risk only)
  │                               ├── quality-gate  (static checks + tests)
  │                               └── committer     (git commit + tracking)
  │                               │
  │                          next story...
  │                               │
  │  6. Review commits       ◄── done
```

## Usage

### Step 0: Project Init (optional)

Use the architect agent once per project, or any time you need to (re)establish quality gates.

```
Use the architect agent to initialize this project
```

### Step 1: Strategy (interactive)

Open Claude Code in your project and invoke the strategist:

```
Use the strategist agent to plan [your feature description]
```

The strategist will:

- Research your codebase (tech stack, patterns, existing tests)
- Look up relevant library docs via Context7, Codex, and Gemini
- Ask you 3-5 clarifying questions about scope, priority, and risk
- Decompose the feature into small, dependency-ordered user stories
- Write `docs/tasks/task-<name>.json`

This is where you focus your energy. The better the stories and acceptance criteria, the better the autonomous execution.

A task can be an epic or a single feature. Use the depth that fits your app.

### Step 2: Review task-<name>.json (optional)

Check that stories are small enough (one context window each), ordered by dependency, and have clear acceptance criteria. Edit directly if needed.

### Step 2.5: View tasks in the dashboard

```bash
./ralph-plus/dashboard.sh --list
./ralph-plus/dashboard.sh task-<name>.json
```

### Step 3: Run the loop

```bash
./ralph-plus/run-monitored.sh --task task-<name>.json [max_iterations]
```

Default is 10 iterations. Each iteration implements one story. The script:

1. Reads the selected `task-<name>.json`, picks the highest priority story where `passes: false`
2. Runs the 5-agent pipeline for that story
3. If all stories pass, exits with success
4. Otherwise, starts the next iteration for the next story
5. Stops at max iterations if not all stories are done

### Step 4: Check results

Stories that passed have `passes: true` in `task-<name>.json`. Failed stories have details in their `notes` field. Learnings from each story are appended to `progress-<name>.txt` in `docs/tasks/`.

## Pipeline

Each story goes through up to 5 agents sequentially:

```
planner ──► tdd ──► e2e (high-risk only) ──► quality-gate ──► committer
```

### On failure

The quality gate fixes mechanical issues (lint, format, typecheck) via Codex internally. If it still fails, the story is marked failed with details in `notes` and the orchestrator moves to the next story. No retries - failed stories need human attention.

## Setup

### This repo (development)

In ralph-plus itself, `.claude/agents/` is symlinked to `agents/` so edits propagate automatically:

```bash
# Already set up - symlinks point like this:
.claude/agents/strategist.md -> ../../agents/strategist.md
```

### Other projects (quick setup)

```bash
git clone https://github.com/mitchellabrouwer/ralph-plus.git
cd my-project
path/to/ralph-plus/setup.sh
```

The script copies agents, orchestrator scripts, and MCP config into the current directory.

Then:

1. **Initialize architecture** - run the architect agent to create `docs/architecture.md` with your project's quality gates
2. **Create your first task** - describe a feature to the strategist agent, or write a PRD markdown in `docs/tasks/` and convert it to `task-<name>.json`
3. **Run the loop** - `./ralph-plus/run-monitored.sh --task task-<name>.json`

### Third-party skills (npx skills add)

[`npx skills add`](https://github.com/vercel-labs/agent-skills) installs community skills into `.agents/`. These are separate from the `agents/` and `skills/` directories in this repo.

```bash
npx skills add vercel-labs/agent-skills --skill test-driven-development
```

Installed skills land in `.agents/skills/` and can be symlinked into `.claude/skills/`. See the [npx skills docs](https://github.com/vercel-labs/agent-skills) for all options.

### MCPs

Configure the MCP servers your agents need in your project's `.mcp.json`. See `.mcp.json` in this repo for a working example.

| 🏑 Club    | Package                 | Carried by                               |
| ---------- | ----------------------- | ---------------------------------------- |
| Context7   | `@upstash/context7-mcp` | architect, strategist, planner, tdd, e2e |
| Gemini     | `gemini-mcp-tool`       | architect, strategist, planner           |
| Codex      | `codex mcp-server`      | architect, strategist, planner, tdd      |
| Playwright | `@playwright/mcp`       | e2e                                      |

## File Structure

| Location                         | Purpose                                                                                   |
| -------------------------------- | ----------------------------------------------------------------------------------------- |
| `agents/`                        | 🏌️ Player definitions (architect, strategist, planner, tdd, e2e, quality-gate, committer, verify) |
| `.claude/agents/`                | Symlinks to `agents/` (consumed by Claude Code)                                           |
| `ralph-plus/run-monitored.sh`          | Runs pipeline in tmux session (attach/detach anytime)                                     |
| `ralph-plus/run-unmonitored.sh`        | Runs pipeline directly in current shell                                                   |
| `ralph-plus/CLAUDE.md`              | Orchestrator prompt (coordinates the agents)                                              |
| `ralph-plus/dashboard.sh`           | Interactive task dashboard                                                                |
| `docs/tasks/`                    | Task files and progress logs                                                              |
| `docs/tasks/task-<name>.json`    | Stories with pass/fail status (created by strategist)                                     |
| `docs/tasks/progress-<name>.txt` | Append-only learnings log (created at runtime)                                            |
| `docs/architecture.md`           | Project architecture and quality gates (shared across tasks)                              |
| `docs/reference/`                | Legacy Ralph reference (original single-agent flow)                                       |

## Credits

Based on the original Ralph project: <https://github.com/snarktank/ralph>
