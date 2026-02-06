#!/bin/bash
# update_state.sh - Agent state file update script
# User: All agents
#
# Examples:
#   ./scripts/agent/update_state.sh miller working task_xxx
#   ./scripts/agent/update_state.sh miller working task_xxx "Implementing"
#   ./scripts/agent/update_state.sh miller idle
#   ./scripts/agent/update_state.sh miller blocked task_xxx "Stopped due to API error"
#   ./scripts/agent/update_state.sh sifter reviewing task_xxx

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Display help
show_help() {
    cat << EOF
Usage: update_state.sh <agent_name> <status> [current_task] [progress]

Updates the agent's state file (state/*.yaml).

Arguments:
  agent_name    foreman, miller, sifter, gleaner
  status        Valid status for each agent (see below)
  current_task  Current task ID (specify when not idle)
  progress      Current progress status (optional, recommended for working/blocked)

Status list:
  foreman:  idle, working, waiting_patron
  miller:   idle, working, blocked
  sifter:   inactive, idle, reviewing
  gleaner:  inactive, idle, researching

Examples:
  update_state.sh miller working task_20260130_auth "Starting implementation"
  update_state.sh miller blocked task_20260130_auth "External API connection error"
  update_state.sh miller idle
  update_state.sh sifter reviewing task_20260130_auth "Code review in progress"
  update_state.sh gleaner researching task_20260130_auth "Researching libraries"
  update_state.sh foreman waiting_patron task_20260130_auth "Waiting for patron decision"

Notes:
  - When idle/inactive, current_task and progress are automatically cleared
  - When blocked, it's recommended to describe the problem in progress
EOF
    exit 0
}

# Argument check
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

AGENT="$1"
STATUS="$2"
CURRENT_TASK="${3:-null}"
PROGRESS="${4:-}"

# Agent name validation
case "$AGENT" in
    foreman|miller|sifter|gleaner)
        ;;
    *)
        echo "Error: Invalid agent name '$AGENT'"
        echo "Valid agent names: foreman, miller, sifter, gleaner"
        exit 1
        ;;
esac

# Status validation (per agent)
case "$AGENT" in
    foreman)
        case "$STATUS" in
            idle|working|waiting_patron) ;;
            *)
                echo "Error: Invalid Foreman status '$STATUS'"
                echo "Valid statuses: idle, working, waiting_patron"
                exit 1
                ;;
        esac
        ;;
    miller)
        case "$STATUS" in
            idle|working|blocked) ;;
            *)
                echo "Error: Invalid Miller status '$STATUS'"
                echo "Valid statuses: idle, working, blocked"
                exit 1
                ;;
        esac
        ;;
    sifter)
        case "$STATUS" in
            inactive|idle|reviewing) ;;
            *)
                echo "Error: Invalid Sifter status '$STATUS'"
                echo "Valid statuses: inactive, idle, reviewing"
                exit 1
                ;;
        esac
        ;;
    gleaner)
        case "$STATUS" in
            inactive|idle|researching) ;;
            *)
                echo "Error: Invalid Gleaner status '$STATUS'"
                echo "Valid statuses: inactive, idle, researching"
                exit 1
                ;;
        esac
        ;;
esac

STATE_FILE="$MILL_ROOT/state/${AGENT}.yaml"

# File existence check
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE"
    exit 1
fi

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Clear current_task and progress for idle statuses
if [ "$STATUS" = "idle" ] || [ "$STATUS" = "inactive" ]; then
    CURRENT_TASK="null"
    PROGRESS=""
fi

# Handle empty progress (save as empty string in YAML)
if [ -z "$PROGRESS" ]; then
    PROGRESS_VALUE='""'
else
    PROGRESS_VALUE="\"$PROGRESS\""
fi

# Update YAML (update each field with sed)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^status: .*/status: $STATUS/" "$STATE_FILE"
    sed -i '' "s/^current_task: .*/current_task: $CURRENT_TASK/" "$STATE_FILE"
    sed -i '' "s/^progress: .*/progress: $PROGRESS_VALUE/" "$STATE_FILE"
    sed -i '' "s/^last_updated: .*/last_updated: \"$TIMESTAMP\"/" "$STATE_FILE"
else
    # Linux
    sed -i "s/^status: .*/status: $STATUS/" "$STATE_FILE"
    sed -i "s/^current_task: .*/current_task: $CURRENT_TASK/" "$STATE_FILE"
    sed -i "s/^progress: .*/progress: $PROGRESS_VALUE/" "$STATE_FILE"
    sed -i "s/^last_updated: .*/last_updated: \"$TIMESTAMP\"/" "$STATE_FILE"
fi

echo "State updated: $AGENT"
echo "  status: $STATUS"
echo "  current_task: $CURRENT_TASK"
echo "  progress: $PROGRESS"
echo "  last_updated: $TIMESTAMP"
