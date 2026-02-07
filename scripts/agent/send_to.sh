#!/bin/bash
# send_to.sh - Send instructions to agents script
# User: All agents
#
# Examples:
#   ./scripts/agent/send_to.sh miller "Please process tasks/in_progress/task_xxx.yaml"
#   ./scripts/agent/send_to.sh foreman "[MILLER:DONE] task_xxx completed"
#   ./scripts/agent/send_to.sh sifter "[FOREMAN:REVIEW_REQUEST] task_xxx: Please review src/auth.js"

set -e

SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# Display help
show_help() {
    cat << EOF
Usage: send_to.sh <agent_name> "<message>"

Sends a message to the specified agent's tmux pane.
Automatically applies the 2-part send rule for tmux send-keys.

Messages should include a standard marker prefix [AGENT:ACTION] for routing:
  [FOREMAN:REVIEW_REQUEST], [MILLER:DONE], [SIFTER:APPROVE], [GLEANER:DONE], etc.

Agent names:
  foreman  - Foreman (pane 1)
  miller   - Miller (pane 2)
  gleaner  - Gleaner (pane 3)
  sifter   - Sifter (pane 4)
  status   - Status screen (pane 0)

Examples:
  send_to.sh miller "[FOREMAN:ASSIGN] Please process tasks/in_progress/task_xxx.yaml"
  send_to.sh foreman "[MILLER:DONE] task_xxx completed"
  send_to.sh gleaner "[FOREMAN:RESEARCH_REQUEST] task_xxx: Please research React state management"
  send_to.sh sifter "[FOREMAN:REVIEW_REQUEST] task_xxx: Please review src/auth.js"
EOF
    exit 0
}

# Argument check
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TARGET="$1"
MESSAGE="$2"

# Get pane number from agent name
case "$TARGET" in
    status)
        PANE=0
        ;;
    foreman)
        PANE=1
        ;;
    miller)
        PANE=2
        ;;
    gleaner)
        PANE=3
        ;;
    sifter)
        PANE=4
        ;;
    *)
        echo "Error: Invalid agent name '$TARGET'"
        echo "Valid agent names: foreman, miller, gleaner, sifter, status"
        exit 1
        ;;
esac

# Check tmux session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: tmux session '$SESSION_NAME' does not exist"
    echo "Run ./scripts/start.sh first"
    exit 1
fi

# Send message (apply 2-part rule)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.$PANE" "$MESSAGE"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.$PANE" Enter

echo "Sent to: $TARGET (pane $PANE)"
echo "  Message: $MESSAGE"
