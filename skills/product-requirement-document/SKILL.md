---
name: product-requirement-document
description: "PRD reference format for the strategist agent. Do NOT invoke this skill directly. When the user asks to create a PRD, use the strategist agent (Task tool with subagent_type=strategist) which produces both prd-<name>.md and task-<name>.json in one flow."
---

# PRD Generator

Create a PRD at `docs/tasks/prd-<name>.md`. Do NOT implement anything.

## Workflow

1. Use AskUserQuestion for 3-5 clarifying questions (problem, core functionality, scope, risk, success criteria)
2. Use Context7 MCP to look up relevant library/framework docs
3. Generate the PRD using the structure below
4. Resolve ALL design decisions via AskUserQuestion BEFORE writing. Open Questions is only for external unknowns (vendor access, org policy).

## PRD Sections

1. **Introduction/Overview** - what and why
2. **Goals** - measurable objectives (bullets)
3. **User Stories** - see format below
4. **Functional Requirements** - numbered: "FR-1: The system must..."
5. **Non-Goals** - what this will NOT include
6. **Design Considerations** (optional) - UI/UX, existing components to reuse
7. **Technical Considerations** (optional) - constraints, integrations, performance
8. **Success Metrics** - how success is measured
9. **Open Questions** - external unknowns only

## Story Format

```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].
**Risk:** low | medium | high
**Test Requirements:** unit, integration [, e2e]

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Typecheck passes
- [ ] Unit tests pass
```

**Risk levels:** low (CRUD, styling, config) | medium (business logic, API integrations) | high (payments, auth, migrations - gets e2e tests)

## Story Rules

- Each story must fit in ONE pipeline iteration (one context window)
- If you cannot describe the change in 2-3 sentences, split it
- Order by dependency: schema -> backend -> UI -> aggregation views
- Earlier stories must not depend on later ones
- Acceptance criteria must be machine-verifiable

**Sizing examples:** Right-sized: "Add a database column and migration", "Add a UI component to an existing page". Too big (split these): "Build the entire dashboard" -> schema, queries, UI, filters. "Add authentication" -> schema, middleware, login UI, session handling.

## Writing Style

The reader is an AI agent. Be explicit, unambiguous, number requirements, avoid unexplained jargon.

## Checklist

Before saving: questions asked and answered, Context7 docs checked, stories small and ordered by dependency, risk levels assigned, test requirements set, high-risk has e2e, acceptance criteria are verifiable, saved to `docs/tasks/prd-<name>.md`.
