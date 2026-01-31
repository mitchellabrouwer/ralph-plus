---
name: product-requirement-document
description: "PRD reference format for the strategist agent. Do NOT invoke this skill directly. When the user asks to create a PRD, use the strategist agent (Task tool with subagent_type=strategist) which produces both prd-<name>.md and task-<name>.json in one flow."
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for autonomous agent execution.

---

## The Job

1. Receive a feature description from the user
2. Use AskUserQuestion for structured clarifying questions
3. Use Context7 MCP to look up relevant library/framework documentation
4. Generate a structured PRD based on answers
5. Save to `docs/tasks/prd-<name>.md`

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 1: Clarifying Questions

Use the AskUserQuestion tool to ask structured questions. This gives users a clean interface instead of freeform text.

Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Risk Areas:** Are there complex integrations or critical flows?
- **Success Criteria:** How do we know it is done?

**Important:** All design decisions must be resolved via AskUserQuestion BEFORE writing the PRD. Do NOT defer unresolved questions to an "Open Questions" section. If you realize during drafting that a decision is needed, stop and ask first. The Open Questions section is only for genuinely external unknowns (e.g., "waiting on API access from vendor") - never for questions you could have asked the user.

Ask 3-5 questions using AskUserQuestion with clear options. Example:

```
Question: "What is the scope of this feature?"
Options:
  - "Minimal viable version"
  - "Full-featured implementation"
  - "Backend/API only"
  - "Frontend/UI only"
```

---

## Step 2: Documentation Lookup

Use Context7 MCP to look up relevant documentation for the project's tech stack. This helps you write more accurate acceptance criteria and understand integration points.

---

## Step 3: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories

Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist
- **Risk Level:** `low`, `medium`, or `high`
- **Test Requirements:** Which test types are needed

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].
**Risk:** low | medium | high
**Test Requirements:** unit, integration [, e2e]

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck passes
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] **[High-risk only]** E2E tests pass
```

#### Risk Level Guidelines

| Risk | Description | Test Requirements |
|------|-------------|-------------------|
| **low** | Simple CRUD, styling, config changes | unit, integration |
| **medium** | New business logic, data flow changes, API integrations | unit, integration |
| **high** | Payment flows, auth, data migrations, complex state machines | unit, integration, e2e |

High-risk stories automatically get E2E test requirements.

#### Story Sizing

**Each story must be completable in ONE pipeline iteration (one context window).**

The pipeline spawns a fresh agent per iteration with no memory of previous work. If a story is too big, the agent runs out of context before finishing and produces broken code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard" - split into: schema, queries, UI components, filters
- "Add authentication" - split into: schema, middleware, login UI, session handling
- "Refactor the API" - split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

#### Story Ordering

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

### 4. Functional Requirements
Numbered list: "FR-1: The system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Relevant existing components to reuse
- Link to mockups if available

### 7. Technical Considerations (Optional)
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

### 8. Success Metrics
How success is measured.

### 9. Open Questions
Remaining questions or areas needing clarification. This section is ONLY for genuinely external unknowns that cannot be resolved by asking the user (e.g., pending vendor access, undecided org policy). If you find yourself writing a question here that the user could answer, you skipped a clarification step - go back and use AskUserQuestion.

---

## Writing for Autonomous Agents

The PRD reader will be an AI agent in the Ralph+ pipeline. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful
- Acceptance criteria must be machine-verifiable (not vague)

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `docs/tasks/`
- **Filename:** `prd-<name>.md` (kebab-case)

---

## Example PRD

```markdown
# PRD: Task Priority System

## Introduction

Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority, with visual indicators and filtering.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority
- Default new tasks to medium priority

## User Stories

### US-001: Add priority field to database
**Description:** As a developer, I need to store task priority so it persists across sessions.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Add priority column to tasks table: 'high' | 'medium' | 'low' (default 'medium')
- [ ] Generate and run migration successfully
- [ ] Typecheck passes
- [ ] Unit tests pass

### US-002: Display priority indicator on task cards
**Description:** As a user, I want to see task priority at a glance so I know what needs attention first.
**Risk:** low
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Each task card shows colored priority badge (red=high, yellow=medium, gray=low)
- [ ] Priority visible without hovering or clicking
- [ ] Typecheck passes
- [ ] Unit tests pass

### US-003: Add priority selector to task edit
**Description:** As a user, I want to change a task's priority when editing it.
**Risk:** medium
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Priority dropdown in task edit modal
- [ ] Shows current priority as selected
- [ ] Saves immediately on selection change
- [ ] Typecheck passes
- [ ] Unit tests pass
- [ ] Integration tests pass

### US-004: Filter tasks by priority
**Description:** As a user, I want to filter the task list to see only high-priority items when I'm focused.
**Risk:** medium
**Test Requirements:** unit, integration

**Acceptance Criteria:**
- [ ] Filter dropdown with options: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Empty state message when no tasks match filter
- [ ] Typecheck passes
- [ ] Unit tests pass
- [ ] Integration tests pass

## Functional Requirements

- FR-1: Add `priority` field to tasks table ('high' | 'medium' | 'low', default 'medium')
- FR-2: Display colored priority badge on each task card
- FR-3: Include priority selector in task edit modal
- FR-4: Add priority filter dropdown to task list header
- FR-5: Sort by priority within each status column (high to medium to low)

## Non-Goals

- No priority-based notifications or reminders
- No automatic priority assignment based on due date
- No priority inheritance for subtasks

## Technical Considerations

- Reuse existing badge component with color variants
- Filter state managed via URL search params
- Priority stored in database, not computed

## Success Metrics

- Users can change priority in under 2 clicks
- High-priority tasks immediately visible at top of lists
- No regression in task list performance

## Open Questions

- Should priority affect task ordering within a column?
- Should we add keyboard shortcuts for priority changes?
```

---

## Checklist

Before saving the PRD:

- [ ] Used AskUserQuestion for clarifying questions
- [ ] Incorporated user's answers
- [ ] Looked up relevant library docs via Context7
- [ ] User stories are small and specific (one context window each)
- [ ] Every story has a risk level assigned
- [ ] Every story has test requirements specified
- [ ] High-risk stories include E2E test requirements
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `docs/tasks/prd-<name>.md`
