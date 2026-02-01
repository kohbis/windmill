#!/bin/bash
# start_sifter.sh - Sifter (目利き) を起動

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# デフォルトエージェント: claude
AGENT_TYPE="${1:-claude}"

case "$AGENT_TYPE" in
    claude|c) AGENT_CMD="claude --dangerously-skip-permissions" ;;
    codex|x) AGENT_CMD="codex --full-auto" ;;
    copilot|g) AGENT_CMD="copilot --allow-all" ;;
    *) echo "不明なエージェント: $AGENT_TYPE"; exit 1 ;;
esac

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "セッション '$SESSION_NAME' が存在しません"
    echo "   先に ./scripts/start.sh を実行してください"
    exit 1
fi

echo "Sifter (目利き) を起動中..."

# ペイン4でClaudeが既に起動しているかチェック
pane_content=$(tmux capture-pane -t "$SESSION_NAME:$WINDOW_NAME.4" -p | grep -c "claude" || true)

if [ "$pane_content" -gt 0 ]; then
    echo "Sifter (ペイン4) は既に起動しています"
    exit 0
fi

# 職人状態更新（起動時はidle）
sed -i '' 's/^status: .*/status: idle/' "$MILL_ROOT/state/sifter.yaml" 2>/dev/null || \
sed -i 's/^status: .*/status: idle/' "$MILL_ROOT/state/sifter.yaml"

# Claude/Codex自動起動
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "$AGENT_CMD"
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" Enter

echo "Sifter起動完了 (ペイン4)"
echo "   親方から指示を送ってください"
