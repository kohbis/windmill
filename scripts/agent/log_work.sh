#!/bin/bash
# log_work.sh - Task YAML work_log append script
# User: Foreman, Miller
#
# Examples:
#   ./scripts/agent/log_work.sh XXX "Started implementation"
#   ./scripts/agent/log_work.sh XXX "Work complete" "All tests passed"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: log_work.sh <task_id> "<action>" ["<details>"]

Appends an entry to the work_log in task YAML.

Arguments:
  task_id   Task ID (e.g., 20260130_impl_auth_feat)
  action    Description of work performed (required)
  details   Detailed information (optional)

Examples:
  log_work.sh 20260130_impl_auth_feat "Started implementation"
  log_work.sh 20260130_impl_auth_feat "Work complete" "All tests passed"
  log_work.sh 20260130_impl_auth_feat "Addressed review feedback" "Fixed variable names"
  log_work.sh 20260130_impl_auth_feat "Blocked" "Dependency library version issue"
EOF
    exit 0
}

# Argument check
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
ACTION="$2"
DETAILS="${3:-}"

# Find task file
TASK_FILE=""
for dir in pending in_progress completed failed; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "Error: Task '$TASK_ID' not found"
    exit 1
fi

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Escape for safe double-quoted YAML scalar.
yaml_escape() {
    printf '%s' "$1" | perl -0pe 's/\\/\\\\/g; s/"/\\\"/g; s/\r/\\r/g; s/\n/\\n/g'
}

ACTION_ESCAPED=$(yaml_escape "$ACTION")
DETAILS_ESCAPED=$(yaml_escape "$DETAILS")

# Append work_log entry (using awk for both empty and existing cases)
TEMP_FILE=$(mktemp)
if grep -q "^work_log: \[\]" "$TASK_FILE"; then
    # Convert empty array to expanded format
    awk -v ts="$TIMESTAMP" -v action="$ACTION_ESCAPED" -v details="$DETAILS_ESCAPED" '
        /^work_log: \[\]/ {
            print "work_log:"
            print "  - timestamp: \"" ts "\""
            print "    action: \"" action "\""
            if (details != "") {
                print "    details: \"" details "\""
            }
            next
        }
        { print }
    ' "$TASK_FILE" > "$TEMP_FILE"
else
    # Append to existing work_log
    awk -v ts="$TIMESTAMP" -v action="$ACTION_ESCAPED" -v details="$DETAILS_ESCAPED" '
        /^work_log:/ {
            print
            print "  - timestamp: \"" ts "\""
            print "    action: \"" action "\""
            if (details != "") {
                print "    details: \"" details "\""
            }
            next
        }
        { print }
    ' "$TASK_FILE" > "$TEMP_FILE"
fi
mv "$TEMP_FILE" "$TASK_FILE"

echo "work_log appended: $TASK_ID"
echo "  timestamp: $TIMESTAMP"
echo "  action: $ACTION"
if [ -n "$DETAILS" ]; then
    echo "  details: $DETAILS"
fi
