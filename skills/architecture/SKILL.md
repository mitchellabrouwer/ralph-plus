---
name: architecture
description: "Create or update a short architecture note for the project. Use when starting a new project if docs/architecture.md is missing."
---

# Architecture Note

One page max. Only include facts verifiable from the codebase. Prefer bullets over paragraphs. If unsure, leave it out.

## Before Creating

Use AskUserQuestion to confirm: (1) architecture style - clean/hexagonal/layered, (2) project layout - feature-first/layer-first/monorepo, (3) shared types location, (4) max function length - 60/80/100/no limit, (5) testing focus - unit+integration/unit-only/integration+e2e/e2e-critical-only.

## Template

```
# Architecture

One line architecture statement.

## Architecture Style
- Style: clean architecture | hexagonal | layered | other
- Why this style fits:

## Project Structure
- Organized by: feature | layer | other
- Shared types: [path]
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
| Entity | Type + pure functions | [path] |
| Repository | Data access interface + impl | [path] |
| Use case | Orchestration logic | [path] |
| Handler | Input validation, wiring | [path] |
| Hook | UI state wrapper | [path] |

## Dependency Rules
1. Shared types: zero external dependencies
2. Use cases: depend only on interfaces and shared types
3. Repositories: depend on external services
4. Handlers: wire everything together
5. UI: calls use cases, manages view state

## Anti-patterns
- External service imports in use cases
- Duplicated types between frontend/backend
- Business logic in handlers or UI hooks
- Mocking external services instead of interfaces

## Data Fetching
- Prefer server side filtering
- Client side filtering only for small data sets

## Guidelines
- Shared types live in one place and are reused
- Keep functions under 100 lines

## Quality Gates
| Gate | Command |
|------|---------|
| Typecheck | [command or "n/a"] |
| Lint | [command or "n/a"] |
| Format | [command or "n/a"] |
| Test | [command or "n/a"] |
```
