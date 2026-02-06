#!/bin/bash
# setup.sh - Windmill initial setup

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting Windmill setup..."

# Create directories
echo "Creating directories..."
mkdir -p "$MILL_ROOT/tasks/pending"      # Pending tasks
mkdir -p "$MILL_ROOT/tasks/in_progress"  # Tasks in progress
mkdir -p "$MILL_ROOT/tasks/completed"    # Completed tasks
mkdir -p "$MILL_ROOT/tasks/failed"       # Suspended/On hold
mkdir -p "$MILL_ROOT/state"              # Agent state management
mkdir -p "$MILL_ROOT/scripts"
mkdir -p "$MILL_ROOT/agents/foreman"     # Agent-specific directories
mkdir -p "$MILL_ROOT/agents/miller"
mkdir -p "$MILL_ROOT/agents/sifter"
mkdir -p "$MILL_ROOT/agents/gleaner"
mkdir -p "$MILL_ROOT/feedback"           # Feedback from patron

# Initialize agent state files (copy from templates)
echo "Initializing agent states..."

for template in "$MILL_ROOT/state"/*.yaml.template; do
  target="${template%.template}"
  if [ ! -f "$target" ]; then
    cp "$template" "$target"
    echo "  Created $(basename "$target")"
  else
    echo "  $(basename "$target") already exists (skipped)"
  fi
done

# Initialize dashboard.md (copy from template and replace timestamp)
echo "Initializing dashboard.md..."
if [ ! -f "$MILL_ROOT/dashboard.md" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
  sed "s/YYYY-MM-DD HH:MM/$TIMESTAMP/g" "$MILL_ROOT/dashboard.md.template" > "$MILL_ROOT/dashboard.md"
  echo "  Created dashboard.md"
else
  echo "  dashboard.md already exists (skipped)"
fi

# Initialize feedback (copy from templates)
echo "Initializing feedback..."
for template in "$MILL_ROOT/feedback"/*.md.template; do
  target="${template%.template}"
  if [ ! -f "$target" ]; then
    cp "$template" "$target"
    echo "  Created $(basename "$target")"
  else
    echo "  $(basename "$target") already exists (skipped)"
  fi
done

# Create .gitkeep files (to preserve empty directories)
touch "$MILL_ROOT/tasks/pending/.gitkeep"
touch "$MILL_ROOT/tasks/in_progress/.gitkeep"
touch "$MILL_ROOT/tasks/completed/.gitkeep"
touch "$MILL_ROOT/tasks/failed/.gitkeep"

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  ./scripts/start.sh  - Start agents"
echo "  ./scripts/status.sh - Check status"
