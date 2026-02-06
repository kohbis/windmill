#!/bin/bash
# complete_task.sh - Task completion report append script
# User: Foreman
#
# Examples:
#   ./scripts/agent/complete_task.sh task_xxx "Implementation complete summary" "passed"
#   ./scripts/agent/complete_task.sh task_xxx "Bug fix complete" "passed" "Additional optimization recommended"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: complete_task.sh <task_id> "<summary>" "<test_status>" ["<notes>"]

Appends completion report (result section) to task YAML and moves to completed.

Arguments:
  task_id       Task ID (e.g., task_20260130_auth)
  summary       Work summary (required)
  test_status   Test result: passed, failed, skipped
  notes         Additional notes (optional)

Examples:
  complete_task.sh task_20260130_auth "Implemented authentication feature" "passed"
  complete_task.sh task_20260130_auth "Bug fix" "passed" "Additional optimization recommended"
  complete_task.sh task_20260130_auth "Research complete" "skipped" "Not subject to testing"
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

# Find task file (prioritize in_progress)
TASK_FILE=""
for dir in in_progress pending; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        FROM_DIR="$dir"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "Error: Task '$TASK_ID' not found (in_progress or pending)"
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
    echo "Moving only without overwriting"
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

# Move to completed directory
DEST_FILE="$MILL_ROOT/tasks/completed/${TASK_ID}.yaml"
mv "$TASK_FILE" "$DEST_FILE"

echo "Completion processed: $TASK_ID"
echo "  Summary: $SUMMARY"
echo "  Tests: $TEST_STATUS"
echo "  Completed by: $ASSIGNED_TO"
echo "  Moved: $FROM_DIR → completed"
echo "  File: $DEST_FILE"
