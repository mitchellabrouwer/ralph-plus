# Adhoc Improvements

Standalone improvements to the Ralph+ pipeline that sit outside the normal PRD/story flow.

---

## 1. Pipeline Activity Log

**Problem:** Running `run-task-loop.sh` is a black box until completion. The progress log only gets updated after an iteration finishes. No way to see what agents are doing in real time or review what happened at a glance.

**Goal:** Add a top-level activity log that records one-line entries as each agent starts/finishes. Something like:

```
[2026-01-31 20:15:02] orchestrator: picked US-002 (Progress log viewer)
[2026-01-31 20:15:04] planner: produced plan - 3 files, 12 steps
[2026-01-31 20:16:30] tdd: red-green-refactor complete - 8 tests passing
[2026-01-31 20:16:45] quality-gate: PASS (lint clean, 8/8 tests)
[2026-01-31 20:16:50] committer: committed feat: US-002
```

**Design considerations:**
- Plain text, one line per event, human and LLM readable
- Append-only file at `scripts/.activity-log` or `docs/tasks/activity-<slug>.log`
- Orchestrator (scripts/CLAUDE.md) writes entries before/after each agent spawn
- Dashboard can tail this file for live status
- Keep it simple: timestamp + agent + short summary. No JSON overhead.

**Status:** Done

---

## 2. Offload Work to Gemini and Codex

**Problem:** Claude Code token usage is too high. The pipeline burns through Claude tokens on tasks that cheaper models handle well (exploration, doc lookup, boilerplate generation, code review).

**Goal:** Identify which pipeline steps can be delegated to Gemini (`mcp__gemini__ask-gemini`) or Codex (`mcp__codex__codex`) and update agent prompts to prefer them for suitable work.

**Decision:**
- **Planner:** Gemini (`mcp__gemini__ask-gemini`) for codebase analysis, file reading, pattern identification, doc lookups. Claude for final plan synthesis only.
- **TDD:** Claude (no change) - most critical agent, needs production-grade code.
- **Quality gate:** Claude with `model: "haiku"` - just runs commands and reports pass/fail. No code fixes.
- **Committer:** Claude with `model: "haiku"` - mechanical git/file operations.

**Status:** Done

---

## 3. Simplify and Compress Prompt Text

**Problem:** Skill files (SKILL.md), orchestrator instructions (scripts/CLAUDE.md), and agent prompts contain verbose explanations, examples, and templates that consume context window space. The images reference the AGENTS.md pattern from Next.js projects where doc indexes are compressed 80% smaller.

**Goal:** Audit all prompt text and reduce without losing meaning. Shorter prompts = more room for actual work within the context window.

**Results:**
- `scripts/CLAUDE.md`: 130 -> 93 lines (28% reduction)
- `skills/product-requirement-document/SKILL.md`: 294 -> 60 lines (80% reduction)
- `skills/tasks/SKILL.md`: 158 -> 54 lines (66% reduction)
- `skills/git-commit/SKILL.md`: 126 -> 38 lines (70% reduction)
- `skills/architecture/SKILL.md`: 112 -> 66 lines (41% reduction)
- `skills/project-init/SKILL.md`: 42 lines (unchanged, already lean)
- **Total: 862 -> 353 lines (59% reduction)**

**Status:** Done

---

## 4. Fix Skill Invocation by Agents

**Problem:** AI agents are not reliably using skills. The system has skills defined in `skills/*/SKILL.md` but the mapping between "what the agent should do" and "which skill to invoke" is unclear. Agents sometimes ignore skills or use them incorrectly.

**Goal:** Make skill usage deterministic by explicitly mapping skills to agent actions in the orchestrator and agent prompts.

**Specific issues to investigate:**
- Are agents aware of which skills exist?
- Is the skill frontmatter (name, description) being surfaced to agents?
- Do agent prompts reference skills by name?
- Should skills be inlined into agent prompts instead of relying on skill discovery?

**Possible fixes:**
- Add a skill registry section to `scripts/CLAUDE.md` that lists each skill and when to use it
- Update agent prompts to explicitly say "use the git-commit skill for committing"
- Consider embedding key skill content directly in agent prompts rather than relying on tool-based skill loading
- Map: committer -> git-commit skill, strategist -> product-requirement-document skill, planner -> architecture skill

**Status:** Not started
