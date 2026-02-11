#!/bin/bash

# check-security - Find security issues using semgrep
# Usage: check-security [path/to/repo] [--config CONFIG] [--diff [base]]

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Parse Arguments (before dep check so diff mode can skip gracefully)
# ============================================================================

REPO_PATH="."
CONFIG="auto"
DIFF_MODE=false
DIFF_BASE="main"

while [[ $# -gt 0 ]]; do
    case $1 in
        --config|-c)
            CONFIG="$2"
            shift 2
            ;;
        --diff|-d)
            DIFF_MODE=true
            # Optional base branch argument
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                DIFF_BASE="$2"
                shift
            fi
            shift
            ;;
        --help|-h)
            echo "Usage: check-security [path] [--config CONFIG] [--diff [base]]"
            echo ""
            echo "Options:"
            echo "  --config, -c CONFIG  Semgrep ruleset (default: auto)"
            echo "  --diff, -d [base]    Only check files changed vs base branch (default: main)"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Common configs:"
            echo "  auto                 Auto-detect based on project"
            echo "  p/security-audit     Comprehensive security audit"
            echo "  p/owasp-top-ten      OWASP Top 10 vulnerabilities"
            echo "  p/secrets            Detect hardcoded secrets"
            exit 0
            ;;
        *)
            REPO_PATH="$1"
            shift
            ;;
    esac
done

# ============================================================================
# Dependency Check (after arg parsing so diff mode can skip gracefully)
# ============================================================================

for dep in semgrep jq; do
    if ! command -v "$dep" &> /dev/null; then
        if [ "$DIFF_MODE" = true ]; then
            echo -e "${YELLOW}Skipping security check: $dep not installed${NC}"
            case "$dep" in
                semgrep) echo -e "${DIM}  pip install semgrep${NC}" ;;
                jq) echo -e "${DIM}  brew install jq${NC}" ;;
            esac
            exit 0
        else
            echo -e "${RED}${BOLD}Missing dependency: ${YELLOW}$dep${NC}"
            case "$dep" in
                semgrep)
                    echo -e "  ${DIM}pip install semgrep${NC}"
                    echo -e "  ${DIM}# or: brew install semgrep${NC}" ;;
                jq)
                    echo -e "  ${DIM}brew install jq${NC}" ;;
            esac
            exit 1
        fi
    fi
done

REPO_PATH=$(cd "$REPO_PATH" && pwd)

echo ""
echo -e "${BOLD}${MAGENTA}Security Check${NC}"
echo -e "${DIM}Path: $REPO_PATH${NC}"
echo -e "${DIM}Config: $CONFIG${NC}"
if [ "$DIFF_MODE" = true ]; then
    echo -e "${DIM}Mode: diff (vs $DIFF_BASE)${NC}"
fi
echo ""

# ============================================================================
# Diff Mode - Scope to changed files
# ============================================================================

SCAN_TARGETS=()

if [ "$DIFF_MODE" = true ]; then
    cd "$REPO_PATH"
    CHANGED_FILES=$(git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo -e "  ${GREEN}No files to check${NC}"
        echo ""
        exit 0
    fi

    while IFS= read -r file; do
        [ -f "$file" ] && SCAN_TARGETS+=("$file")
    done <<< "$CHANGED_FILES"

    if [ ${#SCAN_TARGETS[@]} -eq 0 ]; then
        echo -e "  ${GREEN}No files to check${NC}"
        echo ""
        exit 0
    fi

    echo -e "${DIM}Checking ${#SCAN_TARGETS[@]} changed files${NC}"
    echo ""
fi

# ============================================================================
# Run Analysis
# ============================================================================

TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

if [ "$DIFF_MODE" = true ]; then
    semgrep scan "${SCAN_TARGETS[@]}" \
        --config "$CONFIG" \
        --json \
        --quiet \
        > "$TEMP_FILE" 2>/dev/null || true
else
    semgrep scan "$REPO_PATH" \
        --config "$CONFIG" \
        --json \
        --quiet \
        --exclude="node_modules" \
        --exclude=".git" \
        --exclude="vendor" \
        --exclude="dist" \
        --exclude="build" \
        --exclude="__pycache__" \
        > "$TEMP_FILE" 2>/dev/null || true
fi

RESULT_COUNT=$(jq '.results | length' "$TEMP_FILE" 2>/dev/null || echo "0")

echo -e "${BOLD}Security issues found:${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
echo ""

if [ "$RESULT_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}No security issues found${NC}"
else
    jq -r '.results[] | [.extra.severity, .check_id, .path, (.start.line | tostring), .extra.message] | @tsv' "$TEMP_FILE" 2>/dev/null | \
    while IFS=$'\t' read -r severity rule_id file_path line_num message; do
        case "$severity" in
            ERROR|error)
                COLOR=$RED
                SEV_LABEL="HIGH"
                ;;
            WARNING|warning)
                COLOR=$YELLOW
                SEV_LABEL="MED "
                ;;
            *)
                COLOR=$CYAN
                SEV_LABEL="LOW "
                ;;
        esac

        REL_PATH="${file_path#$REPO_PATH/}"
        SHORT_RULE=$(echo "$rule_id" | rev | cut -d'.' -f1-2 | rev)

        echo -e "  ${COLOR}${BOLD}[$SEV_LABEL]${NC} ${BOLD}$SHORT_RULE${NC}"
        echo -e "  ${DIM}$REL_PATH:$line_num${NC}"
        echo -e "  ${DIM}$message${NC}"
        echo ""
    done
fi

# ============================================================================
# Summary
# ============================================================================

echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Summary:${NC}"

HIGH=$(jq '[.results[] | select(.extra.severity == "ERROR" or .extra.severity == "error")] | length' "$TEMP_FILE" 2>/dev/null || echo "0")
MED=$(jq '[.results[] | select(.extra.severity == "WARNING" or .extra.severity == "warning")] | length' "$TEMP_FILE" 2>/dev/null || echo "0")
LOW=$(jq '[.results[] | select(.extra.severity != "ERROR" and .extra.severity != "error" and .extra.severity != "WARNING" and .extra.severity != "warning")] | length' "$TEMP_FILE" 2>/dev/null || echo "0")

echo -e "  ${RED}High:${NC} $HIGH  ${YELLOW}Medium:${NC} $MED  ${CYAN}Low:${NC} $LOW  ${DIM}Total: $RESULT_COUNT${NC}"
echo ""

# Exit behavior depends on mode
if [ "$DIFF_MODE" = true ]; then
    # In diff mode: only fail on HIGH severity (semgrep ERROR)
    if [ "$HIGH" -gt 0 ]; then
        exit 1
    fi
else
    # Full scan: fail on any finding
    if [ "$RESULT_COUNT" -gt 0 ]; then
        exit 1
    fi
fi
