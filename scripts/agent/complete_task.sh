#!/bin/bash
# complete_task.sh - Task completion report append script
# User: Foreman
#
# Examples:
#   ./scripts/agent/complete_task.sh XXX "Implementation complete summary" "passed"
#   ./scripts/agent/complete_task.sh XXX "Bug fix complete" "passed" "Additional optimization recommended"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: complete_task.sh <task_id> "<summary>" "<test_status>" ["<notes>"]

Appends completion report (result section) to task YAML.

Arguments:
  task_id       Task ID (e.g., 20260130_impl_auth_feat)
  summary       Work summary (required)
  test_status   Test result: passed, failed, skipped
  notes         Additional notes (optional)

Examples:
  complete_task.sh 20260130_impl_auth_feat "Implemented authentication feature" "passed"
  complete_task.sh 20260130_impl_auth_feat "Bug fix" "passed" "Additional optimization recommended"
  complete_task.sh 20260130_impl_auth_feat "Research complete" "skipped" "Not subject to testing"
EOF
    exit 0
}

# Argument check
if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
SUMMARY="$2"
TEST_STATUS="$3"
NOTES="${4:-}"

# Test status validation
case "$TEST_STATUS" in
    passed|failed|skipped)
        ;;
    *)
        echo "Error: Invalid test status '$TEST_STATUS'"
        echo "Valid statuses: passed, failed, skipped"
        exit 1
        ;;
esac

# Find task file directly
TASK_FILE="$MILL_ROOT/tasks/${TASK_ID}.yaml"
if [ ! -f "$TASK_FILE" ]; then
    echo "Error: Task '$TASK_ID' not found: $TASK_FILE"
    exit 1
fi

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get assigned_to
ASSIGNED_TO=$(grep "^assigned_to:" "$TASK_FILE" | sed 's/^assigned_to: *//' | tr -d '"')
[ "$ASSIGNED_TO" = "null" ] && ASSIGNED_TO="miller"

# Check if completed_at already exists
if grep -q "^completed_at:" "$TASK_FILE"; then
    echo "Warning: This task already has a completion report appended"
    echo "Keeping existing completion report without overwriting"
else
    # Append completion report
    cat >> "$TASK_FILE" << EOF

# --- Completion Report ---
completed_at: "$TIMESTAMP"
completed_by: $ASSIGNED_TO
result:
  summary: |
    $SUMMARY
  tests:
    status: $TEST_STATUS
EOF

    # Add notes if present
    if [ -n "$NOTES" ]; then
        cat >> "$TASK_FILE" << EOF
  notes: |
    $NOTES
EOF
    fi
fi

# Update status to completed
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^status: .*/status: completed/" "$TASK_FILE"
else
    sed -i "s/^status: .*/status: completed/" "$TASK_FILE"
fi

echo "Completion processed: $TASK_ID"
echo "  Summary: $SUMMARY"
echo "  Tests: $TEST_STATUS"
echo "  Completed by: $ASSIGNED_TO"
echo "  Status: completed"
echo "  File: $TASK_FILE"
