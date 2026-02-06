#!/bin/bash
# start_gleaner.sh - Start Gleaner (Researcher)

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# Default agent: claude
AGENT_TYPE="${1:-claude}"

case "$AGENT_TYPE" in
    claude|c) AGENT_CMD="claude --dangerously-skip-permissions" ;;
    codex|x) AGENT_CMD="codex --full-auto" ;;
    copilot|g) AGENT_CMD="copilot --allow-all" ;;
    *) echo "Unknown agent: $AGENT_TYPE"; exit 1 ;;
esac

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' does not exist"
    echo "   Run ./scripts/start.sh first"
    exit 1
fi

echo "Starting Gleaner (Researcher)..."

# Check if Claude is already running in pane 3
pane_content=$(tmux capture-pane -t "$SESSION_NAME:$WINDOW_NAME.3" -p | grep -c "claude" || true)

if [ "$pane_content" -gt 0 ]; then
    echo "Gleaner (pane 3) is already running"
    exit 0
fi

# Update agent state (idle on startup)
sed -i '' 's/^status: .*/status: idle/' "$MILL_ROOT/state/gleaner.yaml" 2>/dev/null || \
sed -i 's/^status: .*/status: idle/' "$MILL_ROOT/state/gleaner.yaml"

# Auto-start Claude/Codex
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" Enter

echo "Gleaner started (pane 3)"
echo "   Send instructions from Foreman"
