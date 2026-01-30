---
name: architecture
description: "Create or update a short architecture note for the project. Use when starting a new project if docs/architecture.md is missing."
---

# Architecture Note

Keep this short and high signal. One page max.

## AskUserQuestion

Use AskUserQuestion to confirm intent before creating the doc. Ask 5 questions with clear options.

1. Architecture style?
   - Clean architecture
   - Hexagonal
   - Layered
   - Other

2. Project layout preference?
   - Feature first
   - Layer first
   - Monorepo packages
   - Other

3. Shared types location?
   - shared/
   - src/types/
   - packages/types/
   - Other

4. Max function length?
   - 60 lines
   - 80 lines
   - 100 lines
   - No limit

5. Testing focus?
   - Unit and integration
   - Unit only
   - Integration and e2e
   - E2e for critical flows only

## Template

```
# Architecture

One line architecture statement.

## Architecture Style
- Style: clean architecture | hexagonal | layered | other
- Why this style fits:

## Project Structure
- Organized by: feature | layer | other
- Shared types and pure functions: [path]
- Frontend root: [path]
- Backend root: [path]

## Core Stack
- Language:
- Framework:
- Runtime:
- Data store:

## Quick Reference
| Term | What it is | Location |
|------|------------|----------|
| Entity | Type plus pure functions | [path] |
| Repository | Data access interface plus implementation | [path] |
| Use case | Orchestration logic | [path] |
| Handler | Input validation, wiring only | [path] |
| Hook | UI state wrapper | [path] |

## Dependency Rules
1. Shared types have zero external dependencies
2. Use cases depend only on interfaces and shared types
3. Repository implementations depend on external services
4. Handlers wire everything together
5. UI calls use cases, manages view state

## Data Fetching
- Prefer server side filtering
- Client side filtering only for small data sets

## Anti-patterns
- Direct external service imports in use cases
- Duplicated types between frontend and backend
- Business logic in handlers or UI hooks
- Mocking external services instead of interfaces

## Quality Gates
| Gate | Command |
|------|---------|
| Typecheck | [command or "n/a"] |
| Lint | [command or "n/a"] |
| Format | [command or "n/a"] |
| Test | [command or "n/a"] |

## Guidelines
- Shared types live in one place and are reused
- Use small modules and keep functions under 100 lines
```

## Rules

- Only include facts you can verify from the codebase or config.
- Prefer short bullets over paragraphs.
- If unsure, leave it out. Do not guess.
- Keep the document under 100 lines.
