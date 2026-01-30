---
name: ralph-plus
description: "Convert PRDs to enhanced prd.json format for the Ralph+ multi-agent pipeline. Use when you have an existing PRD and need to convert it to Ralph+'s JSON format. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json."
---

# Ralph+ PRD Converter

Converts existing PRDs to the enhanced `prd.json` format that Ralph+ uses for autonomous multi-agent execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to `scripts/ralph-plus/prd.json`.

---

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
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

## New Fields (vs. original Ralph format)

### Project-level: `qualityGates`
Specifies which quality checks are enforced for this project. The Quality Gate agent reads this to know which checks to run.

### Per-story: `risk`
Values: `"low"`, `"medium"`, `"high"`

| Risk | When to use |
|------|-------------|
| low | Simple changes: CRUD, styling, config |
| medium | New logic, data flow, API integrations |
| high | Payment, auth, data migrations, complex state |

### Per-story: `testRequirements`
Explicit test coverage requirements:
```json
{
  "unit": true,
  "integration": true,
  "e2e": false
}
```

High-risk stories MUST have `"e2e": true`. Low and medium risk stories have `"e2e": false` unless the PRD explicitly requests E2E testing.

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph+ iteration (one agent pipeline run).**

Ralph+ spawns fresh agents per story with no memory of previous work. If a story is too big, agents run out of context.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - split into schema, queries, UI, filters
- "Add authentication" - split into schema, middleware, login UI, sessions
- "Refactor the API" - split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something an agent can CHECK.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Typecheck passes"
- "Unit tests pass"

### Bad criteria (vague):
- "Works correctly"
- "Good UX"
- "Handles edge cases"

### Always include as final criteria:
```
"Typecheck passes"
"Unit tests pass"
```

For stories with integration test requirements:
```
"Integration tests pass"
```

For UI stories:
```
"Verify in browser using dev-browser skill"
```

For high-risk stories with E2E:
```
"E2E tests pass"
```

---

## Conversion Rules

1. Each user story becomes one JSON entry
2. IDs: Sequential (US-001, US-002, etc.)
3. Priority: Based on dependency order, then document order
4. Risk: Extract from PRD if specified, otherwise assign based on story complexity
5. Test requirements: Derive from risk level and PRD guidance
6. All stories: `passes: false` and empty `notes`
7. branchName: Derive from feature name, kebab-case, prefixed with `ralph/`
8. qualityGates: Set based on project's tooling (check for tsconfig, eslint, prettier configs)

---

## Archiving Previous Runs

**Before writing a new prd.json, check if there is an existing one from a different feature:**

1. Read `scripts/ralph-plus/prd.json` if it exists
2. Check if `branchName` differs from the new feature's branch name
3. If different AND `scripts/ralph-plus/progress.txt` has content beyond the header:
   - Create archive folder: `scripts/ralph-plus/archive/YYYY-MM-DD-feature-name/`
   - Copy current `prd.json` and `progress.txt` to archive
   - Reset `progress.txt` with fresh header

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] Previous run archived (if prd.json exists with different branchName)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has a `risk` level assigned
- [ ] Every story has `testRequirements` specified
- [ ] High-risk stories have `"e2e": true`
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] `qualityGates` matches the project's available tooling
- [ ] Saved to `scripts/ralph-plus/prd.json`
