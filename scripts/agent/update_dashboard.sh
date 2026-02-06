#!/bin/bash
# update_dashboard.sh - Dashboard auto-update script
# User: Foreman
#
# Examples:
#   ./scripts/agent/update_dashboard.sh
#   ./scripts/agent/update_dashboard.sh --log "Sent instructions to Miller"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DASHBOARD="$MILL_ROOT/dashboard.md"

# Display help
show_help() {
    cat << EOF
Usage: update_dashboard.sh [OPTIONS]

Auto-updates dashboard (dashboard.md) from task queue status.

Options:
  --log "<message>"  Add entry to work log
  -h, --help         Show this help

Examples:
  update_dashboard.sh                             # Full update
  update_dashboard.sh --log "Sent instructions to Miller"  # Log append only
EOF
    exit 0
}

# Simple function to get value from YAML
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/  *#.*//' | tr -d '"'
}

# Parse arguments
LOG_MESSAGE=""
LOG_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log)
            LOG_MESSAGE="$2"
            LOG_ONLY=true
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option '$1'"
            show_help
            ;;
    esac
done

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
TIME_ONLY=$(date '+%H:%M')

# Log append only mode
if [ "$LOG_ONLY" = true ] && [ -n "$LOG_MESSAGE" ]; then
    if [ -f "$DASHBOARD" ]; then
        # Append to end of work log section
        echo "- $TIMESTAMP $LOG_MESSAGE" >> "$DASHBOARD"

        # Update last updated
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^Last updated: .*/Last updated: $TIMESTAMP/" "$DASHBOARD"
        else
            sed -i "s/^Last updated: .*/Last updated: $TIMESTAMP/" "$DASHBOARD"
        fi

        echo "Work log appended: $LOG_MESSAGE"
    else
        echo "Error: dashboard.md not found"
        exit 1
    fi
    exit 0
fi

# Full update
# Collect in-progress tasks
IN_PROGRESS=""
for task_file in "$MILL_ROOT/tasks/in_progress"/*.yaml; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        assigned=$(get_yaml_value "$task_file" "assigned_to")
        [[ "$assigned" == "null" ]] && assigned="unassigned"
        IN_PROGRESS="${IN_PROGRESS}- [ ] ${task_id}: ${task_title} (${assigned} assigned)\n"
    fi
done
[ -z "$IN_PROGRESS" ] && IN_PROGRESS="(none)\n"

# Collect completed tasks (latest 5)
COMPLETED=""
completed_files=$(ls -t "$MILL_ROOT/tasks/completed"/*.yaml 2>/dev/null | head -5)
for task_file in $completed_files; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        COMPLETED="${COMPLETED}- [x] ${task_id}: ${task_title}\n"
    fi
done
[ -z "$COMPLETED" ] && COMPLETED="(none)\n"

# Collect pending tasks
PENDING=""
for task_file in "$MILL_ROOT/tasks/pending"/*.yaml; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        PENDING="${PENDING}- ${task_id}: ${task_title}\n"
    fi
done

# Preserve existing work log
EXISTING_LOG=""
if [ -f "$DASHBOARD" ]; then
    EXISTING_LOG=$(awk '/^## Work Log/,0 { if (!/^## Work Log/) print }' "$DASHBOARD")
fi
[ -z "$EXISTING_LOG" ] && EXISTING_LOG="- $TIME_ONLY Dashboard updated"

# Needs attention section
NEEDS_ACTION="(none)"
if [ -n "$PENDING" ]; then
    NEEDS_ACTION="Pending tasks:\n${PENDING}"
fi

# Generate dashboard
cat > "$DASHBOARD" << EOF
# Windmill Dashboard
Last updated: $TIMESTAMP

## In Progress
$(echo -e "$IN_PROGRESS" | sed 's/\\n$//')

## Completed
$(echo -e "$COMPLETED" | sed 's/\\n$//')

## Needs Attention (Waiting for patron decision)
$(echo -e "$NEEDS_ACTION" | sed 's/\\n$//')

## Work Log
$EXISTING_LOG
EOF

echo "Dashboard updated: $DASHBOARD"
