#!/bin/bash

# check-complexity - Find complexity hotspots in your codebase
# Usage: check-complexity [path/to/repo] [--threshold N] [--diff [base]]

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Parse Arguments (before dep check so diff mode can skip gracefully)
# ============================================================================

REPO_PATH="."
THRESHOLD=10
DIFF_MODE=false
DIFF_BASE="main"

while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold|-t)
            THRESHOLD="$2"
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
            echo "Usage: check-complexity [path] [--threshold N] [--diff [base]]"
            echo ""
            echo "Options:"
            echo "  --threshold, -t N    Complexity threshold (default: 10)"
            echo "  --diff, -d [base]    Only check files changed vs base branch (default: main)"
            echo "  --help, -h           Show this help"
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

if ! command -v lizard &> /dev/null; then
    if [ "$DIFF_MODE" = true ]; then
        echo -e "${YELLOW}Skipping complexity check: lizard not installed${NC}"
        echo -e "${DIM}  pip install lizard${NC}"
        exit 0
    else
        echo -e "${RED}${BOLD}Missing dependency:${NC}"
        echo -e "  ${YELLOW}lizard${NC} - cyclomatic complexity analyzer"
        echo -e "    ${DIM}pip install lizard${NC}"
        echo -e "    ${DIM}# or: brew install lizard${NC}"
        exit 1
    fi
fi

REPO_PATH=$(cd "$REPO_PATH" && pwd)

echo ""
echo -e "${BOLD}${CYAN}Complexity Check${NC}"
echo -e "${DIM}Path: $REPO_PATH${NC}"
echo -e "${DIM}Threshold: $THRESHOLD${NC}"
if [ "$DIFF_MODE" = true ]; then
    echo -e "${DIM}Mode: diff (vs $DIFF_BASE)${NC}"
fi
echo ""

# ============================================================================
# Diff Mode - Scope to changed files
# ============================================================================

LIZARD_TARGETS=()

if [ "$DIFF_MODE" = true ]; then
    cd "$REPO_PATH"
    CHANGED_FILES=$(git diff --name-only "$DIFF_BASE"...HEAD -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.go' '*.java' '*.c' '*.cpp' '*.cs' '*.rb' '*.rs' '*.swift' '*.kt' 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo -e "  ${GREEN}No files to check${NC}"
        echo ""
        exit 0
    fi

    while IFS= read -r file; do
        [ -f "$file" ] && LIZARD_TARGETS+=("$file")
    done <<< "$CHANGED_FILES"

    if [ ${#LIZARD_TARGETS[@]} -eq 0 ]; then
        echo -e "  ${GREEN}No files to check${NC}"
        echo ""
        exit 0
    fi

    echo -e "${DIM}Checking ${#LIZARD_TARGETS[@]} changed files${NC}"
    echo ""
fi

# ============================================================================
# Run Analysis (single lizard pass, filter for both sections)
# ============================================================================

if [ "$DIFF_MODE" = true ]; then
    ALL_FUNCS=$(lizard "${LIZARD_TARGETS[@]}" \
        --CCN 0 \
        2>/dev/null | grep -E "^[[:space:]]*[0-9]+" || true)
else
    ALL_FUNCS=$(lizard "$REPO_PATH" \
        --CCN 0 \
        --exclude "**/node_modules/*" \
        --exclude "**/.git/*" \
        --exclude "**/vendor/*" \
        --exclude "**/dist/*" \
        --exclude "**/build/*" \
        --exclude "**/__pycache__/*" \
        2>/dev/null | grep -E "^[[:space:]]*[0-9]+" || true)
fi

# Filter to threshold violations
ISSUE_COUNT=0
HIGH_COUNT=0
RESULTS=""

echo -e "${BOLD}Functions exceeding complexity threshold:${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
echo ""

if [ -n "$ALL_FUNCS" ]; then
    RESULTS=$(echo "$ALL_FUNCS" | awk -v t="$THRESHOLD" '$2 >= t')
fi

if [ -z "$RESULTS" ]; then
    echo -e "  ${GREEN}No functions exceed complexity threshold of $THRESHOLD${NC}"
else
    while read -r line; do
        CCN=$(echo "$line" | awk '{print $2}')
        FUNC_INFO=$(echo "$line" | awk '{print $NF}')

        FUNC_NAME=$(echo "$FUNC_INFO" | cut -d'@' -f1)
        LINE_NUM=$(echo "$FUNC_INFO" | cut -d'@' -f2)
        FILE_PATH=$(echo "$FUNC_INFO" | cut -d'@' -f3-)

        REL_PATH="${FILE_PATH#$REPO_PATH/}"

        if [ "$CCN" -ge 20 ]; then
            COLOR=$RED
            SEVERITY="HIGH"
            HIGH_COUNT=$((HIGH_COUNT + 1))
        elif [ "$CCN" -ge 15 ]; then
            COLOR=$YELLOW
            SEVERITY="MED "
        else
            COLOR=$CYAN
            SEVERITY="LOW "
        fi

        echo -e "  ${COLOR}${BOLD}[$SEVERITY CCN:$CCN]${NC} ${BOLD}$FUNC_NAME${NC}"
        echo -e "  ${DIM}$REL_PATH:$LINE_NUM${NC}"
        echo ""
    done <<< "$RESULTS"

    ISSUE_COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
fi

# ============================================================================
# Top Complex Functions (ranked from same scan)
# ============================================================================

echo -e "${BOLD}Top complex functions:${NC}"
echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
echo ""

if [ -n "$ALL_FUNCS" ]; then
    echo "$ALL_FUNCS" | sort -k2 -rn | head -10 | while read -r line; do
        CCN=$(echo "$line" | awk '{print $2}')
        FUNC_INFO=$(echo "$line" | awk '{print $NF}')
        FUNC_NAME=$(echo "$FUNC_INFO" | cut -d'@' -f1)
        FILE_PATH=$(echo "$FUNC_INFO" | cut -d'@' -f3-)
        REL_PATH="${FILE_PATH#$REPO_PATH/}"

        if [ "$CCN" -ge 20 ]; then
            COLOR=$RED
        elif [ "$CCN" -ge 15 ]; then
            COLOR=$YELLOW
        elif [ "$CCN" -ge 10 ]; then
            COLOR=$CYAN
        else
            COLOR=$DIM
        fi

        printf "  ${COLOR}%3s${NC}  %-30s ${DIM}%s${NC}\n" "$CCN" "$FUNC_NAME" "$REL_PATH"
    done
else
    echo -e "  ${DIM}No functions found${NC}"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Summary:${NC}"

if command -v scc &> /dev/null && [ "$DIFF_MODE" = false ]; then
    TOTAL_COMPLEXITY=$(scc --format json "$REPO_PATH" 2>/dev/null | jq '[.[].Complexity] | add' 2>/dev/null || echo "0")
    TOTAL_FILES=$(scc --format json "$REPO_PATH" 2>/dev/null | jq '[.[].Count] | add' 2>/dev/null || echo "0")

    if [ "$TOTAL_FILES" -gt 0 ] && [ "$TOTAL_COMPLEXITY" != "null" ]; then
        AVG=$(echo "scale=1; $TOTAL_COMPLEXITY / $TOTAL_FILES" | bc 2>/dev/null || echo "N/A")
        echo -e "  Total complexity: $TOTAL_COMPLEXITY across $TOTAL_FILES files (avg: $AVG/file)"
    fi
fi

echo -e "  Issues found: $ISSUE_COUNT (${RED}HIGH: $HIGH_COUNT${NC})"
echo ""

# Exit behavior depends on mode
if [ "$DIFF_MODE" = true ]; then
    # In diff mode: only fail on HIGH severity (CCN >= 20)
    if [ "$HIGH_COUNT" -gt 0 ]; then
        exit 1
    fi
else
    # Full scan: fail on any finding
    if [ "$ISSUE_COUNT" -gt 0 ]; then
        exit 1
    fi
fi
