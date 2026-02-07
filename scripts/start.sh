#!/bin/bash
# start.sh - Windmill tmux session startup (all agents deployed)

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# Help message
show_help() {
    cat << EOF
Usage: $0 [DEFAULT_AGENT] [OPTIONS]

DEFAULT_AGENT: Default for all agents (claude|codex|copilot)
               Default: claude

OPTIONS:
  --foreman AGENT   Specify agent for Foreman
  --miller AGENT    Specify agent for Miller
  --gleaner AGENT   Specify agent for Gleaner
  --sifter AGENT    Specify agent for Sifter
  -h, --help        Show this help

AGENT: claude|codex|copilot (shorthand: c|x|g)

Examples:
  $0                              # All claude
  $0 codex                        # All codex
  $0 --gleaner codex              # Only gleaner is codex, others are claude
  $0 claude --miller copilot      # Only miller is copilot, others are claude
  $0 codex --gleaner claude --sifter claude  # gleaner and sifter are claude, others are codex
EOF
    exit 0
}

# Function to get agent command
get_agent_cmd() {
    local agent_type="$1"
    case "$agent_type" in
        claude|c)
            echo "claude --dangerously-skip-permissions"
            ;;
        codex|x)
            echo "codex --dangerously-bypass-approvals-and-sandbox"
            ;;
        copilot|g)
            echo "copilot --allow-all"
            ;;
        *)
            echo "Unknown agent: $agent_type" >&2
            exit 1
            ;;
    esac
}

# Function to get agent name
get_agent_name() {
    local agent_type="$1"
    case "$agent_type" in
        claude|c) echo "Claude Code" ;;
        codex|x) echo "OpenAI Codex CLI" ;;
        copilot|g) echo "GitHub Copilot CLI" ;;
        *) echo "Unknown" ;;
    esac
}

# Default agent: claude
DEFAULT_AGENT="claude"

# Individual agent settings (default unset)
FOREMAN_AGENT=""
MILLER_AGENT=""
GLEANER_AGENT=""
SIFTER_AGENT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --foreman)
            FOREMAN_AGENT="$2"
            shift 2
            ;;
        --miller)
            MILLER_AGENT="$2"
            shift 2
            ;;
        --gleaner)
            GLEANER_AGENT="$2"
            shift 2
            ;;
        --sifter)
            SIFTER_AGENT="$2"
            shift 2
            ;;
        --*)
            echo "Unknown option: $1"
            echo "Help: $0 --help"
            exit 1
            ;;
        *)
            # Treat first positional argument as default agent
            if [[ -z "$DEFAULT_AGENT" || "$DEFAULT_AGENT" == "claude" ]]; then
                DEFAULT_AGENT="$1"
            else
                echo "Multiple default agents specified: $DEFAULT_AGENT and $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Use default if not individually specified
FOREMAN_AGENT="${FOREMAN_AGENT:-$DEFAULT_AGENT}"
MILLER_AGENT="${MILLER_AGENT:-$DEFAULT_AGENT}"
GLEANER_AGENT="${GLEANER_AGENT:-$DEFAULT_AGENT}"
SIFTER_AGENT="${SIFTER_AGENT:-$DEFAULT_AGENT}"

# Get commands for each agent
FOREMAN_CMD=$(get_agent_cmd "$FOREMAN_AGENT")
MILLER_CMD=$(get_agent_cmd "$MILLER_AGENT")
GLEANER_CMD=$(get_agent_cmd "$GLEANER_AGENT")
SIFTER_CMD=$(get_agent_cmd "$SIFTER_AGENT")

echo "Agent configuration:"
echo "  Foreman: $(get_agent_name "$FOREMAN_AGENT")"
echo "  Miller:  $(get_agent_name "$MILLER_AGENT")"
echo "  Gleaner: $(get_agent_name "$GLEANER_AGENT")"
echo "  Sifter:  $(get_agent_name "$SIFTER_AGENT")"
echo ""

# Check for existing session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "  Session '$SESSION_NAME' already exists"
    echo "   Connect: tmux attach -t $SESSION_NAME"
    echo "   Stop: ./scripts/stop.sh"
    exit 1
fi

echo "Starting Windmill..."

# Reset dashboard from template
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
sed "s/YYYY-MM-DD HH:MM/$TIMESTAMP/g" "$MILL_ROOT/dashboard.md.template" > "$MILL_ROOT/dashboard.md"
echo "Dashboard reset: dashboard.md"

# Create tmux session
tmux new-session -d -s "$SESSION_NAME" -n "$WINDOW_NAME" -x 200 -y 50

# Wait for session creation
sleep 0.2

echo "Creating pane structure..."

# Layout:
# ┌─────────────────┬──────────────┬──────────────┐
# │                 │  Foreman(1)  │   Miller(2)  │
# │   Status(0)     ├──────────────┼──────────────┤
# │                 │  Sifter(4)   │  Gleaner(3)  │
# └─────────────────┴──────────────┴──────────────┘

# Step 1: Horizontal split to create right pane (left 30%, right 70%)
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.0" -h -p 70
# pane 0 = Status (left 30%), pane 1 = right area (70%)

# Step 2: Further horizontal split to create right pane (center 35%, right 35%)
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.1" -h -p 50
# pane 0 = Status (30%), pane 1 = center (35%), pane 2 = right (35%)

# Step 3: Vertical split right (pane 2) first
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.2" -v
# pane 2 = top right, pane 3 = bottom right

# Step 4: Vertical split center (pane 1)
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.1" -v
# pane 1 = top center, pane 4 = bottom center

# Wait for pane structure completion
sleep 0.5

echo "Setting pane titles..."

# Enable pane title display
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "

# Set title for each pane
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.0" -T "Status"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1" -T "Foreman"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.2" -T "Miller"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.3" -T "Gleaner"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.4" -T "Sifter"

echo "Setting directories for each pane..."

# Pane 0: Status (left)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.0" "cd $MILL_ROOT" Enter

# Pane 1: Foreman (top center)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "cd $MILL_ROOT/agents/foreman" Enter

# Pane 2: Miller (top right)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" "cd $MILL_ROOT/agents/miller" Enter

# Pane 3: Gleaner (bottom right)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "cd $MILL_ROOT/agents/gleaner" Enter

# Pane 4: Sifter (bottom center)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "cd $MILL_ROOT/agents/sifter" Enter

# Wait for command completion
sleep 0.3

echo "Preparing agents..."

# Start status monitor (left pane)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.0" "watch -n 5 ./scripts/status.sh" Enter

# Auto-start all agents
sleep 0.3

# Foreman (pane 1)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "$FOREMAN_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" Enter
sleep 0.2

# Miller (pane 2)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" "$MILLER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" Enter
sleep 0.2

# Gleaner (pane 3)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "$GLEANER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" Enter
sleep 0.2

# Sifter (pane 4)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "$SIFTER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" Enter
sleep 0.2

# Select Foreman pane
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1"

echo "Created tmux session '$SESSION_NAME'"
echo ""
echo "Agent configuration:"
echo "  [1] Foreman: $(get_agent_name "$FOREMAN_AGENT")"
echo "  [2] Miller:  $(get_agent_name "$MILLER_AGENT")"
echo "  [3] Gleaner: $(get_agent_name "$GLEANER_AGENT")"
echo "  [4] Sifter:  $(get_agent_name "$SIFTER_AGENT")"
echo ""
echo "Layout:"
echo "   ┌─────────────┬─────────────┬─────────────┐"
echo "   │             │ [1] Foreman │ [2] Miller  │"
echo "   │ [0] Status  ├─────────────┼─────────────┤"
echo "   │             │ [4] Sifter  │ [3] Gleaner │"
echo "   └─────────────┴─────────────┴─────────────┘"
echo ""
echo "Connect: tmux attach -t $SESSION_NAME"
echo ""
echo "All agents are at their posts"
echo "   Emergency stop: Ctrl+C or ./scripts/stop.sh"
