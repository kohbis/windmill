#!/bin/bash
# move_task.sh - Task status transition script
# User: Foreman
#
# Examples:
#   ./scripts/agent/move_task.sh task_20260130_auth in_progress miller
#   ./scripts/agent/move_task.sh task_20260130_auth completed
#   ./scripts/agent/move_task.sh task_20260130_auth failed

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: move_task.sh <task_id> <to_status> [assigned_to]

Transitions (moves) a task to the specified status.

Arguments:
  task_id      Task ID (e.g., task_20260130_auth)
  to_status    Destination status: pending, in_progress, completed, failed
  assigned_to  Assignee (required for in_progress): miller, sifter, gleaner

Examples:
  move_task.sh task_20260130_auth in_progress miller  # Assign to Miller
  move_task.sh task_20260130_auth completed           # Complete
  move_task.sh task_20260130_auth failed              # Suspend/On hold
  move_task.sh task_20260130_auth pending             # Return to pending
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
    pending|in_progress|completed|failed)
        ;;
    *)
        echo "Error: Invalid status '$TO_STATUS'"
        echo "Valid statuses: pending, in_progress, completed, failed"
        exit 1
        ;;
esac

# in_progress requires assigned_to
if [ "$TO_STATUS" = "in_progress" ] && [ "$ASSIGNED_TO" = "null" ]; then
    echo "Error: in_progress requires assignee (assigned_to)"
    echo "Usage: move_task.sh $TASK_ID in_progress <miller|sifter|gleaner>"
    exit 1
fi

# Find task file
TASK_FILE=""
for dir in pending in_progress completed failed; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        FROM_STATUS="$dir"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "Error: Task '$TASK_ID' not found"
    exit 1
fi

# Moving to same status is unnecessary
if [ "$FROM_STATUS" = "$TO_STATUS" ]; then
    echo "Task is already in $TO_STATUS"
    exit 0
fi

# Destination path
DEST_FILE="$MILL_ROOT/tasks/$TO_STATUS/${TASK_ID}.yaml"

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

# Move file
mv "$TASK_FILE" "$DEST_FILE"

echo "Moved: $FROM_STATUS → $TO_STATUS"
echo "  Task: $TASK_ID"
echo "  Assigned: $ASSIGNED_TO"
echo "  File: $DEST_FILE"
