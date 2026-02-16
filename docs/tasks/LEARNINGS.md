# Codebase Learnings

## pipeline-observability (2026-02-16)

1. **bats test structural assertions**: Use `declare -f` to inspect function body for structural assertions. Example: `declare -f main_loop | grep -q "UP)"` verifies that a specific case branch exists in the function definition without needing to execute the function.

2. **shellcheck quality bar**: `--severity=warning` is the effective quality gate for bash code. Info and style findings are pre-existing and not blockers. Focus linting on warnings and errors only.

3. **bats section boundary detection (macOS/BSD awk)**: Use awk to extract sections bounded by markdown headings: `awk '/^## SectionName/{found=1; next} found && /^## /{exit} found{n++} END{print n+0}' file` counts lines in the section. This avoids sed limitations on macOS (no -i flag, can't use | head -n -1 reliably). The pattern: find start, skip it (next), exit on next heading, count intermediate lines.
