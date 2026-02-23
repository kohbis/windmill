#!/bin/bash
# status.sh - Windmill status display

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# Check if agent process is running in a tmux pane
# Returns 0 if the pane's shell has child processes (agent running)
is_pane_active() {
    local pane_index="$1"
    local pane_pid
    pane_pid=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME.$pane_index" -F '#{pane_pid}' 2>/dev/null)
    if [ -n "$pane_pid" ]; then
        if pgrep -P "$pane_pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Simple function to get value from YAML (remove comments)
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/  *#.*//' | tr -d '"'
}

# Build task file list from flat tasks directory
shopt -s nullglob
TASK_FILES=("$MILL_ROOT/tasks"/*.yaml)
shopt -u nullglob

# Find first matching task ID by assignee and status
find_task_id_by_assignee_status() {
    local assignee="$1"
    local target_status="$2"
    local task_file task_status task_assigned task_id

    for task_file in "${TASK_FILES[@]}"; do
        task_status=$(get_yaml_value "$task_file" "status")
        task_assigned=$(get_yaml_value "$task_file" "assigned_to")
        if [ "$task_status" = "$target_status" ] && [ "$task_assigned" = "$assignee" ]; then
            task_id=$(get_yaml_value "$task_file" "id")
            echo "${task_id:-$(basename "$task_file" .yaml)}"
            return 0
        fi
    done
    return 1
}

# Find first task requiring Foreman involvement
find_foreman_task_id() {
    local task_file task_status task_id
    for task_file in "${TASK_FILES[@]}"; do
        task_status=$(get_yaml_value "$task_file" "status")
        case "$task_status" in
            planning|in_progress|review)
                task_id=$(get_yaml_value "$task_file" "id")
                echo "${task_id:-$(basename "$task_file" .yaml)}"
                return 0
                ;;
        esac
    done
    return 1
}

# Count tasks by status using status field grep
count_tasks_by_status() {
    local target_status="$1"
    if [ ${#TASK_FILES[@]} -eq 0 ]; then
        echo "0"
        return
    fi
    grep -h -E "^status: *${target_status}([[:space:]]|$)" "${TASK_FILES[@]}" 2>/dev/null | wc -l | tr -d ' '
}

echo "═══════════════════════════════════════════════════════════"
echo "  WINDMILL STATUS - $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Agent status
echo "[Agent Status]"
echo "───────────────────────────────────────────────────────────"

# Foreman (pane 1)
if foreman_task=$(find_foreman_task_id); then
    foreman_status="working"
elif is_pane_active 1; then
    foreman_status="active"
    foreman_task="none"
else
    foreman_status="idle"
    foreman_task="none"
fi
printf "  %-12s │ %-10s │ %s\n" "Foreman" "$foreman_status" "$foreman_task"

# Miller (pane 2)
if miller_task=$(find_task_id_by_assignee_status "miller" "in_progress"); then
    miller_status="working"
elif is_pane_active 2; then
    miller_status="active"
    miller_task="none"
else
    miller_status="idle"
    miller_task="none"
fi
printf "  %-12s │ %-10s │ %s\n" "Miller" "$miller_status" "$miller_task"

# Sifter (pane 4)
if sifter_task=$(find_task_id_by_assignee_status "sifter" "review"); then
    sifter_status="reviewing"
elif is_pane_active 4; then
    sifter_status="active"
    sifter_task="none"
else
    sifter_status="idle"
    sifter_task="none"
fi
printf "  %-12s │ %-10s │ %s\n" "Sifter" "$sifter_status" "$sifter_task"

# Gleaner (pane 3)
if gleaner_task=$(find_task_id_by_assignee_status "gleaner" "planning"); then
    gleaner_status="researching"
elif is_pane_active 3; then
    gleaner_status="active"
    gleaner_task="none"
else
    gleaner_status="idle"
    gleaner_task="none"
fi
printf "  %-12s │ %-10s │ %s\n" "Gleaner" "$gleaner_status" "$gleaner_task"

echo ""

# Task queue status
echo "[Task Queue]"
echo "───────────────────────────────────────────────────────────"

planning_count=$(count_tasks_by_status "planning")
pending_count=$(count_tasks_by_status "pending")
in_progress_count=$(count_tasks_by_status "in_progress")
review_count=$(count_tasks_by_status "review")
completed_count=$(count_tasks_by_status "completed")
failed_count=$(count_tasks_by_status "failed")

printf "  %-15s │ %3d items  (planning with Gleaner)\n" "planning" "$planning_count"
printf "  %-15s │ %3d items  (pending tasks)\n" "pending" "$pending_count"
printf "  %-15s │ %3d items  (tasks in progress)\n" "in_progress" "$in_progress_count"
printf "  %-15s │ %3d items  (under review)\n" "review" "$review_count"
printf "  %-15s │ %3d items  (completed)\n" "completed" "$completed_count"
printf "  %-15s │ %3d items  (suspended/on hold)\n" "failed" "$failed_count"

echo ""

# In-progress task details
if [ "$in_progress_count" -gt 0 ]; then
    echo "[In-Progress Task Details]"
    echo "───────────────────────────────────────────────────────────"
    for task_file in "${TASK_FILES[@]}"; do
        task_status=$(get_yaml_value "$task_file" "status")
        if [ "$task_status" = "in_progress" ]; then
            task_id=$(get_yaml_value "$task_file" "id")
            task_title=$(get_yaml_value "$task_file" "title")
            assigned=$(get_yaml_value "$task_file" "assigned_to")
            [ -z "$task_id" ] && task_id="$(basename "$task_file" .yaml)"
            [[ "$assigned" == "null" ]] && assigned="unassigned"
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
