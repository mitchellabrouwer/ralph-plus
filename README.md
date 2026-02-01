# Ralph+ ⛳

A multi-agent pipeline for autonomous feature implementation using TDD.

## Concepts

Think of Ralph+ like a golf team.

**🏌️ Players (Agents)** - Each player has a specific role on the team. The strategist reads the course. The planner picks the shot. The tdd player executes. They know their job, but they don't all need the same equipment or training.

**📋 Training (Skills)** - Techniques a player can draw on when the situation calls for it. A player might choose between different approaches depending on the lie - deep research vs shallow research, different testing strategies. Multiple players can share the same training. Skills are switchable: the agent reads the one that fits the situation.

**🏑 Clubs (MCPs)** - Different clubs for different shots. You wouldn't putt with a driver. Each player's bag only has the clubs they need. The strategist carries research clubs (Codex, Gemini, Context7). The e2e player carries the Playwright set. The quality-gate carries nothing - it just reads the scorecard.

|     | Concept  | Directory   | What it is                                    |
| --- | -------- | ----------- | --------------------------------------------- |
| 🏌️  | Players  | `agents/`   | Agent definitions - who does what             |
| 📋  | Training | `skills/`   | Methodology and techniques agents can draw on |
| 🏑  | Clubs    | `.mcp.json` | External tools (AI models, browser, docs)     |

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

## How It Works

You handle strategy. The agents handle everything else.

```
 YOU                          AGENTS (autonomous)
  │                               │
  │  1. Describe feature          │
  │  2. Answer questions ◄────►  strategist (researches, asks, produces task-<name>.json)
  │  3. Architect           ◄──  (if first time or feature outside current arch)
  │  4. Review task-<name>.json         │
  │  5. Run run-task-loop.sh            │
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
./scripts/dashboard.sh --list
./scripts/dashboard.sh task-<name>.json
```

### Step 3: Run the loop

```bash
./scripts/run-task-loop.sh --task task-<name>.json [max_iterations]
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

### Failure escalation

When quality-gate or e2e fails, the orchestrator retries with increasing scope:

```
FAIL
 ├── Retry 1: re-run tdd with failure context, then re-verify
 ├── Retry 2: re-run planner + tdd (new approach), then re-verify
 └── Retry 3: mark story failed in task-<name>.json notes, move to next story
```

Each retry passes the specific failure details (error output, what check failed) so the agent can make targeted fixes rather than guessing.

## Setup

### This repo (development)

In ralph-plus itself, `.claude/agents/` and `.claude/skills/` are symlinked to `agents/` and `skills/` so edits propagate automatically:

```bash
# Already set up - symlinks point like this:
.claude/agents/strategist.md -> ../../agents/strategist.md
.claude/skills/architecture   -> ../../skills/architecture/
```

### Other projects

Copy agents, skills, and scripts into your project:

```bash
mkdir -p .claude/agents .claude/skills
cp path/to/ralph-plus/agents/*.md .claude/agents/
cp -r path/to/ralph-plus/skills/* .claude/skills/
cp -r path/to/ralph-plus/scripts .
```

### Third-party skills (npx skills add)

[`npx skills add`](https://github.com/vercel-labs/agent-skills) installs community skills into `.agents/`. These are separate from the custom `agents/` and `skills/` directories in this repo.

```bash
# Install a skill from GitHub
npx skills add vercel-labs/agent-skills

# Install specific skills
npx skills add vercel-labs/agent-skills --skill frontend-design

# Install from a local path
npx skills add ./my-local-skills

# List available skills in a repo
npx skills add vercel-labs/agent-skills --list
```

Installed skills land in `.agents/skills/` and are symlinked into `.claude/skills/` automatically. See the [npx skills docs](https://github.com/vercel-labs/agent-skills) for all options (`--global`, `--agent`, `--skill`, `--all`, etc).

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
| `agents/`                        | 🏌️ Player definitions (architect, strategist, planner, tdd, e2e, quality-gate, committer) |
| `skills/`                        | 📋 Reference materials (testing-anti-patterns)                                            |
| `.agents/`                       | 📦 Third-party skills installed via `npx skills add`                                      |
| `.claude/agents/`                | Symlinks to `agents/` (consumed by Claude Code)                                           |
| `.claude/skills/`                | Symlinks to `skills/` and `.agents/skills/` (consumed by Claude Code)                     |
| `scripts/run-task-loop.sh`       | Bash loop that runs one story per iteration                                               |
| `scripts/CLAUDE.md`              | Orchestrator prompt (coordinates the agents)                                              |
| `docs/tasks/`                    | Task files and progress logs                                                              |
| `docs/tasks/task-<name>.json`    | Stories with pass/fail status (created by strategist)                                     |
| `docs/tasks/progress-<name>.txt` | Append-only learnings log (created at runtime)                                            |
| `docs/architecture.md`           | Short architecture notes shared across tasks                                              |
| `scripts/dashboard.sh`           | Interactive task dashboard                                                                |
| `docs/reference/ralph/`          | Legacy Ralph reference (original single agent flow)                                       |

## Credits

Based on the original Ralph project: <https://github.com/snarktank/ralph>
