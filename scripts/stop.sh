#!/bin/bash
# stop.sh - Windmill 全職人停止

SESSION_NAME="windmill"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "セッション '$SESSION_NAME' は存在しません"
    exit 0
fi

echo "Windmill を停止中..."

# 各ペインにCtrl+Cを送信してClaudeを終了
for pane in 0 1 2 3; do
    if tmux list-panes -t "$SESSION_NAME:0" 2>/dev/null | grep -q "^$pane:"; then
        tmux send-keys -t "$SESSION_NAME:0.$pane" C-c
        sleep 0.5
    fi
done

# セッション終了
tmux kill-session -t "$SESSION_NAME"

echo "セッション '$SESSION_NAME' を終了しました"
