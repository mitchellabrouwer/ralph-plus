---
name: git-commit
description: "Git commit conventions and operations for the Ralph+ pipeline. Defines commit message format, branch naming, and staging rules. Used by the Committer agent."
---

# Git Commit Conventions

## Commit Format

- Implementation: `feat: US-001 - Story title`
- Tracking: `chore: mark US-001 as passing` / `chore: update progress log for US-001`

## Branch Naming

Format: `ralph/[feature-name-kebab-case]` (from task file `branchName`). Branch from `main`.

## Staging Rules

Always stage specific files by name. Never use `git add -A` or `git add .`.

## Never Commit

`.env*`, credentials (`*.key`, `*.pem`, `credentials.json`), `scripts/tmp/`, `node_modules/`, build artifacts (`dist/`, `.next/`, `build/`), OS files (`.DS_Store`, `Thumbs.db`). Add to `.gitignore` if not listed.

## Workflow

1. `git status` to see changes
2. `git diff` to review
3. `git add <specific files>`
4. `git commit -m "feat: US-001 - Story title"`
5. `git status` to verify

## Atomic Commits

Two commits per story:
1. `feat: US-001 - ...` for source code
2. `chore: mark US-001 as passing` for task file and progress log updates
