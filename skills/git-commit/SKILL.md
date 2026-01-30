---
name: git-commit
description: "Git commit conventions and operations for the Ralph+ pipeline. Defines commit message format, branch naming, and staging rules. Used by the Committer agent."
---

# Git Commit Conventions

Consistent git operations for the Ralph+ pipeline.

---

## Commit Message Format

```
feat: [Story ID] - [Story Title]
```

Examples:
```
feat: US-001 - Add status field to tasks table
feat: US-003 - Display status badge on task cards
```

For tracking/housekeeping updates:
```
chore: mark US-001 as passing
chore: update progress log for US-001
```

---

## Branch Naming

Format: `ralph/[feature-name-kebab-case]`

Derived from the `branchName` field in `prd.json`. Always branch from `main`.

```bash
git checkout main
git pull
git checkout -b ralph/feature-name
```

If the branch already exists, check it out:
```bash
git checkout ralph/feature-name
```

---

## Staging Rules

**Always stage specific files.** Never use:
- `git add -A`
- `git add .`

These can accidentally include sensitive files or artifacts.

Instead:
```bash
git add src/components/Feature.tsx src/utils/helper.ts
```

Use `git status` to see what changed, then stage only the relevant files.

---

## Files to Never Commit

- `.env` and `.env.*` files
- Credential files (`credentials.json`, `*.key`, `*.pem`)
- `scripts/ralph-plus/tmp/` directory contents
- `node_modules/`
- Build artifacts (`dist/`, `.next/`, `build/`)
- OS files (`.DS_Store`, `Thumbs.db`)

If any of these appear in `git status`, do NOT stage them. Add to `.gitignore` if not already listed.

---

## Commit Workflow

### 1. Check status
```bash
git status
```

### 2. Review changes
```bash
git diff
```

### 3. Stage specific files
```bash
git add <file1> <file2> ...
```

### 4. Commit with conventional message
```bash
git commit -m "feat: US-001 - Story title"
```

### 5. Verify
```bash
git status
git log --oneline -1
```

---

## Atomic Commits

Keep commits focused:

1. **Implementation commit:** All source code changes for the story
   ```
   feat: US-001 - Add status field to tasks table
   ```

2. **Tracking commit:** prd.json and progress.txt updates
   ```
   chore: mark US-001 as passing
   ```

This separation makes it easy to revert implementation without losing tracking data, or vice versa.
