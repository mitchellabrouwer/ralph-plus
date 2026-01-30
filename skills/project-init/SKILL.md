---
name: project-init
description: "Initialize a project with architecture and quality gates. Use when starting a new codebase or before the first PRD to create docs/architecture.md and set up typecheck, lint, format, and test commands."
---

# Project Init

Set up architecture and quality gates from day one. Keep it minimal and aligned with the existing stack.

## Workflow

1. **Read architecture**
   - If `docs/architecture.md` exists, read it and follow it.
   - If it does not exist, use AskUserQuestion as defined in `skills/architecture/SKILL.md`, then create it using the template.

2. **Inventory tooling**
   - Find the language and tooling from config files.
   - Look for: package.json, tsconfig, eslint config, prettier config, test config.

3. **Define quality gates**
   - Use the architecture doc to decide what must be enforced.
   - Keep the list short and practical: typecheck, lint, format, tests.

4. **Wire commands**
   - Discover the project's existing tooling and wire runnable commands for: typecheck, lint, format check, and tests.
   - Reuse existing tooling. Do not introduce new frameworks unless required by the architecture doc.
   - Record the exact commands in the Quality Gates table in `docs/architecture.md`. Mark any gate that does not apply as "n/a".

5. **Lint rules**
   - If linting exists, add or align a rule for max function length of 100 lines.
   - If linting does not exist, set it up only when the stack is clear and common (for example JS or TS).

6. **Verify**
   - Run the quality gate commands to confirm they work.
   - If a gate cannot be set up, document it in `docs/architecture.md` under Guidelines.

## Rules

- Do not over engineer. Prefer the smallest viable setup.
- Use the architecture doc as the source of truth for what to enforce.
- If the stack is unclear, ask the user before adding new tools.
