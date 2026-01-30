---
name: initiative-prd
description: "Create an initiative PRD JSON with risk, test requirements, and clarifying questions. Use when planning a new epic or feature and you need docs/initiatives/prd-<initiative>.json."
---

# Initiative PRD Generator

Create a PRD directly in the Ralph+ `prd-<initiative>.json` format, with risk levels, test requirements, and structured clarifying questions.

---

## The Job

1. Receive a feature description from the user
2. Use AskUserQuestion for structured clarifying questions
3. Use Context7 MCP to look up relevant library/framework documentation
4. Generate a structured PRD with risk levels and test requirements
5. Write `docs/initiatives/prd-<initiative>.json`

**Important:** Do NOT start implementing. Just create `prd-<initiative>.json`.

---

## Step 1: Clarifying Questions

Use the AskUserQuestion tool to ask structured questions. This gives users a clean interface instead of freeform text.

Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Risk Areas:** Are there complex integrations or critical flows?
- **Success Criteria:** How do we know it is done?

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

Use these sections to shape the content, but output only JSON. Map goals and requirements into the PRD `description` and story acceptance criteria. Architecture notes belong in `docs/architecture.md`.

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

### 4. Functional Requirements
Numbered list: "FR-1: The system must..."

### 5. Non-Goals (Out of Scope)
What this feature will NOT include.

### 6. Quality Gates
Specify which quality checks apply to this project:
- TypeScript compilation
- Linting
- Formatting
- Unit tests
- Integration tests

### 7. Design Considerations (Optional)
UI/UX requirements, mockups, existing components to reuse.

### 8. Technical Considerations (Optional)
Constraints, dependencies, integration points, performance.

### 9. Success Metrics
How success is measured.

### 10. Open Questions
Remaining areas needing clarification.

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

- **Format:** JSON (`.json`)
- **Location:** `docs/initiatives/`
- **Filename:** `prd-<initiative>.json`

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description from PRD title or intro]",
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

Before saving the PRD:

- [ ] Used AskUserQuestion for clarifying questions
- [ ] Incorporated user's answers
- [ ] User stories are small and specific (one context window each)
- [ ] Every story has a risk level assigned
- [ ] Every story has test requirements specified
- [ ] High-risk stories include E2E test requirements
- [ ] Acceptance criteria include quality gates (typecheck, tests)
- [ ] UI stories do not add browser verification criteria unless explicitly requested
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Quality gates section specifies which checks apply
- [ ] Saved to `docs/initiatives/prd-<initiative>.json`
