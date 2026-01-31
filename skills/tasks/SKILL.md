---
name: tasks
description: "Convert a PRD markdown file into a task JSON for the Ralph+ pipeline. Use when you have docs/tasks/prd-<name>.md and need docs/tasks/task-<name>.json."
---

# Task JSON Converter

Convert a `docs/tasks/prd-<name>.md` into the Ralph+ `task-<name>.json` execution manifest.

---

## The Job

1. Read the specified `docs/tasks/prd-<name>.md`
2. Extract and convert stories, risk levels, test requirements, and quality gates
3. Write `docs/tasks/task-<name>.json`

**Important:** Do NOT start implementing. Just create `task-<name>.json`.

---

## Step 1: Read the PRD

Read the PRD markdown at `docs/tasks/prd-<name>.md`. Parse all sections - the PRD follows the structure defined in `skills/prd/SKILL.md`.

---

## Step 2: Conversion Rules

### Stories

- Each `### US-NNN:` section becomes one JSON story entry
- Extract id, title, description, acceptance criteria, risk, and test requirements
- IDs: Sequential (US-001, US-002, etc.)
- Priority: Based on document order (first story = priority 1)
- All stories start with `passes: false` and empty `notes`

### Risk Mapping

| PRD Risk | `risk` field | `testRequirements` |
|----------|-------------|-------------------|
| low | `"low"` | `{ "unit": true, "integration": true, "e2e": false }` |
| medium | `"medium"` | `{ "unit": true, "integration": true, "e2e": false }` |
| high | `"high"` | `{ "unit": true, "integration": true, "e2e": true }` |

### Quality Gates

Derive from the PRD's Quality Gates section if present, or from the project's tooling (tsconfig, eslint, prettier, test runner). Defaults:

```json
{
  "typescript": true,
  "linting": true,
  "formatting": true,
  "unitTests": true,
  "integrationTests": true
}
```

### Story Sizing Validation

Each story must be completable in ONE pipeline iteration (one context window). If a PRD story looks too large, split it before converting. Signs a story is too big:

- More than 5 acceptance criteria
- Touches more than 3 files
- Cannot be described in 2-3 sentences

### Story Ordering Validation

Stories must be ordered by dependency. Verify:
1. Schema/database changes come first
2. Backend logic comes before UI that depends on it
3. No story depends on a later story

If the PRD ordering is wrong, reorder and adjust priority numbers accordingly.

### PRD Field

Every task JSON must include a `prd` field pointing to the source PRD:

```json
"prd": "docs/tasks/prd-<name>.md"
```

### Description

Pull from the PRD's Introduction/Overview or title.

### Branch Name

Derive from the feature name: `ralph/<feature-name-kebab-case>`.

---

## Output

- **Format:** JSON (`.json`)
- **Location:** `docs/tasks/`
- **Filename:** `task-<name>.json`

## Output Format

```json
{
  "project": "[Project Name]",
  "prd": "docs/tasks/prd-<name>.md",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description from PRD intro]",
  "qualityGates": {
    "typescript": true,
    "linting": true,
    "formatting": true,
    "unitTests": true,
    "integrationTests": true
  },
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes",
        "Unit tests pass",
        "Integration tests pass"
      ],
      "priority": 1,
      "risk": "low",
      "testRequirements": {
        "unit": true,
        "integration": true,
        "e2e": false
      },
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Checklist

Before saving the task JSON:

- [ ] Read the PRD markdown file
- [ ] Every story extracted with correct risk and test requirements
- [ ] High-risk stories have `e2e: true`
- [ ] Stories are ordered by dependency (priority numbers match)
- [ ] Each story is small enough for one context window
- [ ] No story depends on a later story
- [ ] Acceptance criteria include quality gates (typecheck, tests)
- [ ] `prd` field set to the source PRD path
- [ ] Quality gates derived from project tooling
- [ ] Saved to `docs/tasks/task-<name>.json`
