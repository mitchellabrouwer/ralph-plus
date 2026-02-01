---
name: tasks
description: "Convert a PRD markdown file into a task JSON for the Ralph+ pipeline. Use when you have docs/tasks/prd-<name>.md and need docs/tasks/task-<name>.json."
---

# Task JSON Converter

Read `docs/tasks/prd-<name>.md`, convert to `docs/tasks/task-<name>.json`. Do NOT implement anything.

## Conversion Rules

- Each `### US-NNN:` section becomes one story entry
- Extract: id, title, description, acceptance criteria, risk, test requirements
- Priority = document order (first story = priority 1)
- All stories start with `passes: false` and empty `notes`
- `prd` field points to source PRD: `"prd": "docs/tasks/prd-<name>.md"`
- `branchName`: `ralph/<feature-name-kebab-case>`
- `description`: from PRD Introduction/Overview

## Risk Mapping

| Risk | testRequirements |
|------|-----------------|
| low | `{ "unit": true, "integration": true, "e2e": false }` |
| medium | `{ "unit": true, "integration": true, "e2e": false }` |
| high | `{ "unit": true, "integration": true, "e2e": true }` |

## Quality Gates

Derive from PRD or project tooling. Defaults: `{ "typescript": true, "linting": true, "formatting": true, "unitTests": true, "integrationTests": true }`

## Validation

- Each story must fit ONE pipeline iteration. Split if: >5 acceptance criteria, >3 files touched, or cannot describe in 2-3 sentences.
- Stories ordered by dependency: schema -> backend -> UI. No story depends on a later one. Reorder if PRD is wrong.

## Output Format

```json
{
  "project": "[Name]", "prd": "docs/tasks/prd-<name>.md",
  "branchName": "ralph/[kebab-case]", "description": "[From PRD intro]",
  "qualityGates": { "typescript": true, "linting": true, "formatting": true, "unitTests": true, "integrationTests": true },
  "userStories": [{
    "id": "US-001", "title": "[Title]",
    "description": "As a [user], I want [feature] so that [benefit]",
    "acceptanceCriteria": ["Criterion 1", "Typecheck passes", "Unit tests pass"],
    "priority": 1, "risk": "low",
    "testRequirements": { "unit": true, "integration": true, "e2e": false },
    "passes": false, "notes": ""
  }]
}
```
