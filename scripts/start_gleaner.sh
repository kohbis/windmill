#!/bin/bash
# start_gleaner.sh - Gleaner (聞き役) を起動

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "セッション '$SESSION_NAME' が存在しません"
    echo "   先に ./scripts/start.sh を実行してください"
    exit 1
fi

echo "Gleaner (聞き役) を起動中..."

# ペイン3でClaudeが既に起動しているかチェック
pane_content=$(tmux capture-pane -t "$SESSION_NAME:$WINDOW_NAME.3" -p | grep -c "claude" || true)

if [ "$pane_content" -gt 0 ]; then
    echo "Gleaner (ペイン3) は既に起動しています"
    exit 0
fi

# 職人状態更新（起動時はidle）
sed -i '' 's/^status: .*/status: idle/' "$MILL_ROOT/state/gleaner.yaml" 2>/dev/null || \
sed -i 's/^status: .*/status: idle/' "$MILL_ROOT/state/gleaner.yaml"

# Claude自動起動（権限スキップモード）
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "claude --dangerously-skip-permissions"
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" Enter

echo "Gleaner起動完了 (ペイン3)"
echo "   親方から指示を送ってください"
