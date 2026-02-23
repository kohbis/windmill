#!/bin/bash
# update_plan.sh - Script to add implementation plan to task YAML
# User: Foreman (used after receiving plan report from Gleaner)
#
# Examples:
#   ./scripts/agent/update_plan.sh 20260130_impl_auth_feat "React" "Lightweight and proven" "small"
#   ./scripts/agent/update_plan.sh --approve 20260130_impl_auth_feat

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: update_plan.sh [OPTIONS] <task_id> [plan info...]

Adds implementation plan to task YAML or records patron approval.

Mode 1: Add plan
  update_plan.sh <task_id> "<tech>" "<reason>" "<size>" ["<step1>" "<step2>"...] ["--risk" "<risk1>" "<risk2>"...]

Mode 2: Record patron approval
  update_plan.sh --approve <task_id>

Options:
  --approve       Record patron approval and change status to pending
  --arch <text>   Architecture description
  --risk <risks>  Risks/concerns (multiple allowed)
  -h, --help      Show this help

Sizes:
  small   - Small scale (single file, simple changes)
  medium  - Medium scale (multiple files, standard implementation)
  large   - Large scale (many files, complex implementation)

Examples:
  # Add plan
  update_plan.sh 20260130_impl_auth_feat "lodash" "Lightweight and proven" "small" "Create util" "Add tests"

  # With risks
  update_plan.sh 20260130_impl_auth_feat "React" "Standard" "medium" "Create component" --risk "CSS conflict" "No IE support"

  # Patron approval
  update_plan.sh --approve 20260130_impl_auth_feat
EOF
    exit 0
}

# Parse arguments
APPROVE_MODE=false
ARCHITECTURE=""
RISKS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --approve)
            APPROVE_MODE=true
            shift
            ;;
        --arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        --risk)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                RISKS+=("$1")
                shift
            done
            ;;
        -h|--help)
            show_help
            ;;
        *)
            break
            ;;
    esac
done

# Get task ID
if [ $# -lt 1 ]; then
    echo "Error: Task ID required"
    show_help
fi

TASK_ID="$1"
shift

# Search for task file directly
TASK_FILE="$MILL_ROOT/tasks/${TASK_ID}.yaml"
if [ ! -f "$TASK_FILE" ]; then
    echo "Error: Task file not found: $TASK_FILE"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Patron approval mode
if [ "$APPROVE_MODE" = true ]; then
    # Update patron_approved in plan section
    if grep -q "patron_approved:" "$TASK_FILE"; then
        sed -i.bak "s/patron_approved: false/patron_approved: true/" "$TASK_FILE"
        sed -i.bak "s/approved_at: null/approved_at: \"$TIMESTAMP\"/" "$TASK_FILE"
    else
        # If plan section doesn't exist, append
        cat >> "$TASK_FILE" << EOF

# Patron approval
patron_approved: true
approved_at: "$TIMESTAMP"
EOF
    fi

    # Change status to pending
    sed -i.bak "s/status: planning/status: pending/" "$TASK_FILE"

    # Delete backup
    rm -f "${TASK_FILE}.bak"

    echo "Patron approval recorded: $TASK_FILE"
    echo "Status: pending (ready for implementation)"
    echo ""
    echo "Next step: Send implementation instructions to Miller"
    echo "  move_task.sh $TASK_ID in_progress miller"
    echo "  send_to.sh miller \"[FOREMAN:ASSIGN] Please process $TASK_FILE\""
    exit 0
fi

# Plan addition mode
if [ $# -lt 3 ]; then
    echo "Error: Plan addition requires tech, reason, and size"
    echo "Usage: update_plan.sh <task_id> \"<tech>\" \"<reason>\" \"<size>\" [steps...]"
    exit 1
fi

TECH="$1"
REASON="$2"
SIZE="$3"
shift 3

# Remaining are implementation steps
IMPL_STEPS=()
while [[ $# -gt 0 && "$1" != "--risk" ]]; do
    IMPL_STEPS+=("$1")
    shift
done

# If --risk comes, collect risks
if [[ "$1" == "--risk" ]]; then
    shift
    while [[ $# -gt 0 ]]; do
        RISKS+=("$1")
        shift
    done
fi

# Delete existing commented plan section
sed -i.bak '/^# --- Implementation Plan/,/^#   approved_at:/d' "$TASK_FILE"

# Append plan section
cat >> "$TASK_FILE" << EOF

# --- Implementation Plan (result of planning with Gleaner) ---
plan:
  tech_selection: "$TECH"
  tech_reason: |
    $REASON
EOF

# Architecture
if [ -n "$ARCHITECTURE" ]; then
    cat >> "$TASK_FILE" << EOF
  architecture: |
    $ARCHITECTURE
EOF
else
    cat >> "$TASK_FILE" << EOF
  architecture: null
EOF
fi

# Implementation steps
echo "  implementation_steps:" >> "$TASK_FILE"
if [ ${#IMPL_STEPS[@]} -gt 0 ]; then
    for step in "${IMPL_STEPS[@]}"; do
        echo "    - \"$step\"" >> "$TASK_FILE"
    done
else
    echo "    - \"(Steps undefined)\"" >> "$TASK_FILE"
fi

# Risks
echo "  risks:" >> "$TASK_FILE"
if [ ${#RISKS[@]} -gt 0 ]; then
    for risk in "${RISKS[@]}"; do
        echo "    - \"$risk\"" >> "$TASK_FILE"
    done
else
    echo "    - null" >> "$TASK_FILE"
fi

# Meta information
cat >> "$TASK_FILE" << EOF
  estimated_size: $SIZE
  planned_by: gleaner
  planned_at: "$TIMESTAMP"
  patron_approved: false
  approved_at: null
EOF

# Delete backup
rm -f "${TASK_FILE}.bak"

echo "Plan added: $TASK_FILE"
echo ""
echo "Next step: Report plan to patron and obtain approval"
echo "After approval: update_plan.sh --approve $TASK_ID"
