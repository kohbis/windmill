#!/bin/bash
# stop.sh - Windmill stop all agents

SESSION_NAME="windmill"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' does not exist"
    exit 0
fi

echo "Stopping Windmill..."

# Send Ctrl+C to each pane to terminate agents
for pane in 0 1 2 3; do
    if tmux list-panes -t "$SESSION_NAME:0" 2>/dev/null | grep -q "^$pane:"; then
        tmux send-keys -t "$SESSION_NAME:0.$pane" C-c
        sleep 0.5
    fi
done

# Kill session
tmux kill-session -t "$SESSION_NAME"

echo "Session '$SESSION_NAME' terminated"
