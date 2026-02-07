#!/bin/bash
# create_task.sh - Task YAML creation script
# User: Foreman
#
# Examples:
#   ./scripts/agent/create_task.sh "Implement authentication" "Step 1" "Step 2" "Step 3"
#   ./scripts/agent/create_task.sh --id custom_id "Title" "Step 1"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_FILE="$MILL_ROOT/tasks/task.yaml.template"

# Display help
show_help() {
    cat << EOF
Usage: create_task.sh [OPTIONS] "<title>" "<step1>" [<step2>...]

Creates a task YAML in tasks/pending/.
Template: Uses tasks/task.yaml.template

Options:
  --id <id>       Specify custom ID (default: YYYYMMDD_<3-5 token slug>)
  --context <text> Add context information
  --status <status> Initial status (default: planning)
  -h, --help      Show this help

Status:
  planning    - Planning in progress (waiting for planning with Gleaner)
  pending     - Plan confirmed, waiting for implementation (patron approved)

Examples:
  create_task.sh "Implement authentication" "Create login screen" "API integration" "Add tests"
  create_task.sh --id 20260130_impl_auth_feat "Authentication" "Step 1"
  create_task.sh --context "Continuation from before" "Bug fix" "Investigate cause" "Implement fix"
  create_task.sh --status pending "Simple fix" "Fix typo"
EOF
    exit 0
}

# Parse arguments
CUSTOM_ID=""
CONTEXT=""
INITIAL_STATUS="planning"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)
            CUSTOM_ID="$2"
            shift 2
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        --status)
            INITIAL_STATUS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            break
            ;;
    esac
done

# Minimum argument check
if [ $# -lt 2 ]; then
    echo "Error: Title and at least one step required"
    echo "Usage: create_task.sh \"<title>\" \"<step1>\" [<step2>...]"
    exit 1
fi

TITLE="$1"
shift
STEPS=("$@")

# Generate ID
if [ -n "$CUSTOM_ID" ]; then
    TASK_ID="$CUSTOM_ID"
else
    DATE_PART=$(date '+%Y%m%d')
    # Generate slug: split title into words, take 3-5 tokens, lowercase
    SLUG=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9 ]//g' | tr '[:upper:]' '[:lower:]' | tr -s ' ' '\n' | head -5 | tail -5 | tr '\n' '_' | sed 's/_$//')
    # Ensure minimum 3 tokens (pad with "task" if needed)
    TOKEN_COUNT=$(echo "$SLUG" | tr '_' '\n' | wc -l | tr -d ' ')
    while [ "$TOKEN_COUNT" -lt 3 ]; do
        SLUG="${SLUG}_task"
        TOKEN_COUNT=$((TOKEN_COUNT + 1))
    done
    if [ -z "$SLUG" ]; then
        SLUG="unnamed_task_item"
    fi
    TASK_ID="${DATE_PART}_${SLUG}"
fi

TASK_FILE="$MILL_ROOT/tasks/pending/${TASK_ID}.yaml"

# Check if exists
if [ -f "$TASK_FILE" ]; then
    echo "Error: $TASK_FILE already exists"
    exit 1
fi

# Check template
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    echo "Run setup.sh first"
    exit 1
fi

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Generate YAML from template (basic part only, excluding comment lines)
cat > "$TASK_FILE" << EOF
id: $TASK_ID
title: "$TITLE"
status: $INITIAL_STATUS
assigned_to: null
patron_input_required: false
breakdown:
EOF

# Add steps
STEP_NUM=1
for step in "${STEPS[@]}"; do
    echo "  - step${STEP_NUM}: \"$step\"" >> "$TASK_FILE"
    ((STEP_NUM++))
done

# Plan section (add as comment, to be activated after planning with Gleaner)
cat >> "$TASK_FILE" << 'EOF'

# --- Implementation Plan (added after planning with Gleaner) ---
# plan:
#   tech_selection: ""
#   tech_reason: |
#
#   architecture: |
#
#   implementation_steps:
#     - ""
#   risks:
#     - ""
#   estimated_size: medium
#   planned_by: gleaner
#   planned_at: ""
#   patron_approved: false
#   approved_at: null
EOF

# Add context (optional)
if [ -n "$CONTEXT" ]; then
    cat >> "$TASK_FILE" << EOF

context: |
  $CONTEXT
EOF
fi

# work_log and created_at
cat >> "$TASK_FILE" << EOF

work_log: []
created_at: "$TIMESTAMP"
EOF

echo "Created: $TASK_FILE"
echo "ID: $TASK_ID"
echo "Status: $INITIAL_STATUS"
if [ "$INITIAL_STATUS" = "planning" ]; then
    echo ""
    echo "Next step: Send plan request to Gleaner"
    echo "  send_to.sh gleaner \"[FOREMAN:PLAN_REQUEST] ${TASK_ID}: ...\""
fi
