#!/bin/bash
# move_task.sh - Task status transition script
# User: Foreman
#
# Examples:
#   ./scripts/agent/move_task.sh 20260130_impl_auth_feat in_progress miller
#   ./scripts/agent/move_task.sh 20260130_impl_auth_feat completed
#   ./scripts/agent/move_task.sh 20260130_impl_auth_feat failed

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: move_task.sh <task_id> <to_status> [assigned_to]

Transitions (updates) a task to the specified status.

Arguments:
  task_id      Task ID (e.g., 20260130_impl_auth_feat)
  to_status    Destination status: planning, pending, in_progress, review, completed, failed
  assigned_to  Assignee (required for in_progress/review/planning): miller, sifter, gleaner

Examples:
  move_task.sh 20260130_impl_auth_feat planning gleaner     # Assign planning to Gleaner
  move_task.sh 20260130_impl_auth_feat in_progress miller   # Assign to Miller
  move_task.sh 20260130_impl_auth_feat review sifter        # Assign review to Sifter
  move_task.sh 20260130_impl_auth_feat completed            # Complete
  move_task.sh 20260130_impl_auth_feat failed               # Suspend/On hold
  move_task.sh 20260130_impl_auth_feat pending              # Return to pending
EOF
    exit 0
}

# Argument check
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
TO_STATUS="$2"
ASSIGNED_TO="${3:-null}"

# Status validation
case "$TO_STATUS" in
    planning|pending|in_progress|review|completed|failed)
        ;;
    *)
        echo "Error: Invalid status '$TO_STATUS'"
        echo "Valid statuses: planning, pending, in_progress, review, completed, failed"
        exit 1
        ;;
esac

# in_progress/review/planning require assigned_to
if [ "$ASSIGNED_TO" = "null" ]; then
    case "$TO_STATUS" in
        in_progress|review|planning)
            echo "Error: $TO_STATUS requires assignee (assigned_to)"
            echo "Usage: move_task.sh $TASK_ID $TO_STATUS <miller|sifter|gleaner>"
            exit 1
            ;;
    esac
fi

# Find task file directly
TASK_FILE="$MILL_ROOT/tasks/${TASK_ID}.yaml"
if [ ! -f "$TASK_FILE" ]; then
    echo "Error: Task '$TASK_ID' not found: $TASK_FILE"
    exit 1
fi

# Current status
FROM_STATUS=$(grep "^status:" "$TASK_FILE" | sed 's/^status: *//' | tr -d '"')

# Check current assignee
CURRENT_ASSIGNED=$(grep "^assigned_to:" "$TASK_FILE" | sed 's/^assigned_to: *//' | tr -d '"')

# Skip if both status and assignee are unchanged
if [ "$FROM_STATUS" = "$TO_STATUS" ] && [ "$CURRENT_ASSIGNED" = "$ASSIGNED_TO" ]; then
    echo "Task is already in $TO_STATUS (assigned: $ASSIGNED_TO)"
    exit 0
fi

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Update YAML status
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^status: .*/status: $TO_STATUS/" "$TASK_FILE"
    sed -i '' "s/^assigned_to: .*/assigned_to: $ASSIGNED_TO/" "$TASK_FILE"
else
    # Linux
    sed -i "s/^status: .*/status: $TO_STATUS/" "$TASK_FILE"
    sed -i "s/^assigned_to: .*/assigned_to: $ASSIGNED_TO/" "$TASK_FILE"
fi

# Add completed_at for completed status
if [ "$TO_STATUS" = "completed" ]; then
    # Check if completed_at already exists
    if ! grep -q "^completed_at:" "$TASK_FILE"; then
        echo "completed_at: \"$TIMESTAMP\"" >> "$TASK_FILE"
    fi
fi

echo "Status updated: $FROM_STATUS → $TO_STATUS"
echo "  Task: $TASK_ID"
echo "  Assigned: $ASSIGNED_TO"
echo "  File: $TASK_FILE"
