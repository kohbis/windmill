#!/bin/bash
# status.sh - Windmill status display

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Simple function to get value from YAML (remove comments)
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/  *#.*//' | tr -d '"'
}

echo "═══════════════════════════════════════════════════════════"
echo "  WINDMILL STATUS - $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Agent status
echo "[Agent Status]"
echo "───────────────────────────────────────────────────────────"

# Foreman
foreman_status=$(get_yaml_value "$MILL_ROOT/state/foreman.yaml" "status")
foreman_task=$(get_yaml_value "$MILL_ROOT/state/foreman.yaml" "current_task")
[[ "$foreman_task" == "null" ]] && foreman_task=""
printf "  %-12s │ %-10s │ %s\n" "Foreman" "${foreman_status:-unknown}" "${foreman_task:-none}"

# Miller
miller_status=$(get_yaml_value "$MILL_ROOT/state/miller.yaml" "status")
miller_task=$(get_yaml_value "$MILL_ROOT/state/miller.yaml" "current_task")
[[ "$miller_task" == "null" ]] && miller_task=""
printf "  %-12s │ %-10s │ %s\n" "Miller" "${miller_status:-unknown}" "${miller_task:-none}"

# Sifter
sifter_status=$(get_yaml_value "$MILL_ROOT/state/sifter.yaml" "status")
sifter_task=$(get_yaml_value "$MILL_ROOT/state/sifter.yaml" "current_task")
[[ "$sifter_task" == "null" ]] && sifter_task=""
printf "  %-12s │ %-10s │ %s\n" "Sifter" "${sifter_status:-inactive}" "${sifter_task:-none}"

# Gleaner
gleaner_status=$(get_yaml_value "$MILL_ROOT/state/gleaner.yaml" "status")
gleaner_task=$(get_yaml_value "$MILL_ROOT/state/gleaner.yaml" "current_task")
[[ "$gleaner_task" == "null" ]] && gleaner_task=""
printf "  %-12s │ %-10s │ %s\n" "Gleaner" "${gleaner_status:-inactive}" "${gleaner_task:-none}"

echo ""

# Task queue status
echo "[Task Queue]"
echo "───────────────────────────────────────────────────────────"

pending_count=$(find "$MILL_ROOT/tasks/pending" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
in_progress_count=$(find "$MILL_ROOT/tasks/in_progress" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
completed_count=$(find "$MILL_ROOT/tasks/completed" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
failed_count=$(find "$MILL_ROOT/tasks/failed" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

printf "  %-15s │ %3d items  (pending tasks)\n" "pending/" "$pending_count"
printf "  %-15s │ %3d items  (tasks in progress)\n" "in_progress/" "$in_progress_count"
printf "  %-15s │ %3d items  (completed)\n" "completed/" "$completed_count"
printf "  %-15s │ %3d items  (suspended/on hold)\n" "failed/" "$failed_count"

echo ""

# In-progress task details
if [ "$in_progress_count" -gt 0 ]; then
    echo "[In-Progress Task Details]"
    echo "───────────────────────────────────────────────────────────"
    for task_file in "$MILL_ROOT/tasks/in_progress"/*.yaml; do
        if [ -f "$task_file" ]; then
            task_id=$(get_yaml_value "$task_file" "id")
            task_title=$(get_yaml_value "$task_file" "title")
            task_status=$(get_yaml_value "$task_file" "status")
            assigned=$(get_yaml_value "$task_file" "assigned_to")
            printf "  %s: %s\n" "$task_id" "$task_title"
            printf "    Status: %s  Assigned: %s\n" "$task_status" "${assigned:-unassigned}"
        fi
    done
    echo ""
fi

# Dashboard display
if [ -f "$MILL_ROOT/dashboard.md" ]; then
    echo "[Dashboard]"
    echo "───────────────────────────────────────────────────────────"
    # Display first 20 lines (remove header)
    head -20 "$MILL_ROOT/dashboard.md" | tail -n +2
    echo ""
fi

echo "═══════════════════════════════════════════════════════════"
