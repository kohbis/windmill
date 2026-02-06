#!/bin/bash
# start_sifter.sh - Start Sifter (Reviewer)

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

echo "Starting Sifter (Reviewer)..."

# Check if Claude is already running in pane 4
pane_content=$(tmux capture-pane -t "$SESSION_NAME:$WINDOW_NAME.4" -p | grep -c "claude" || true)

if [ "$pane_content" -gt 0 ]; then
    echo "Sifter (pane 4) is already running"
    exit 0
fi

# Update agent state (idle on startup)
sed -i '' 's/^status: .*/status: idle/' "$MILL_ROOT/state/sifter.yaml" 2>/dev/null || \
sed -i 's/^status: .*/status: idle/' "$MILL_ROOT/state/sifter.yaml"

# Auto-start Claude/Codex
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" Enter

echo "Sifter started (pane 4)"
echo "   Send instructions from Foreman"
