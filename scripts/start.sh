#!/bin/bash
# start.sh - Windmill tmuxセッション起動（全職人配置）

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# 既存セッションチェック
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "  セッション '$SESSION_NAME' は既に存在します"
    echo "   接続: tmux attach -t $SESSION_NAME"
    echo "   停止: ./scripts/stop.sh"
    exit 1
fi

echo "Windmill (風車小屋) を起動中..."

# tmuxセッション作成
tmux new-session -d -s "$SESSION_NAME" -n "$WINDOW_NAME" -x 200 -y 50

# セッション作成を待つ
sleep 0.2

# レイアウト構築（ペイン作成のみ）
# ┌─────────────────┬──────────────┬──────────────┐
# │                 │   Miller     │   Sifter     │
# │   Foreman       │   (ペイン2)  │   (ペイン3)  │
# │   (ペイン0)     │              │              │
# │                 ├──────────────┼──────────────┤
# ├─────────────────┤   Gleaner    │   (予備)     │
# │   Status        │   (ペイン4)  │   (ペイン5)  │
# │   (ペイン1)     │              │              │
# └─────────────────┴──────────────┴──────────────┘

echo "ペイン構造を作成中..."

# レイアウト:
# ┌─────────────────┬──────────────┬──────────────┐
# │                 │  Foreman(1)  │   Miller(2)  │
# │   Status(0)     ├──────────────┼──────────────┤
# │                 │  Sifter(4)   │  Gleaner(3)  │
# └─────────────────┴──────────────┴──────────────┘

# Step 1: 横分割で右に新ペインを作成（左30%, 右70%）
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.0" -h -p 70
# pane 0 = Status (左30%), pane 1 = 右エリア (70%)

# Step 2: さらに横分割で右に新ペインを作成（中央35%, 右35%）
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.1" -h -p 50
# pane 0 = Status (30%), pane 1 = 中央 (35%), pane 2 = 右 (35%)

# Step 3: 右(pane 2)を先に縦分割
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.2" -v
# pane 2 = 右上, pane 3 = 右下

# Step 4: 中央(pane 1)を縦分割
tmux split-window -t "$SESSION_NAME:$WINDOW_NAME.1" -v
# pane 1 = 中央上, pane 4 = 中央下

# ペイン構造完成を待つ
sleep 0.5

echo "ペインにタイトルを設定中..."

# ペインタイトル表示を有効化
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "

# 各ペインにタイトルを設定
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.0" -T "Status"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1" -T "Foreman"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.2" -T "Miller"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.3" -T "Gleaner"
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.4" -T "Sifter"

echo "各ペインのディレクトリを設定中..."

# ペイン0: Status (左)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.0" "cd $MILL_ROOT" Enter

# ペイン1: Foreman (中央上)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "cd $MILL_ROOT/agents/foreman" Enter

# ペイン2: Miller (右上)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" "cd $MILL_ROOT/agents/miller" Enter

# ペイン3: Gleaner (右下)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "cd $MILL_ROOT/agents/gleaner" Enter

# ペイン4: Sifter (中央下)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "cd $MILL_ROOT/agents/sifter" Enter

# コマンド送信完了を待つ
sleep 0.3

echo "職人起動中..."

# Status監視を起動（左ペイン）
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.0" "watch -n 5 ./scripts/status.sh" Enter

# Foremanペインを選択
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1"

# Foremanを自動起動（権限スキップで自動実行モード）
sleep 0.3
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "claude --dangerously-skip-permissions"
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" Enter

echo "tmuxセッション '$SESSION_NAME' を作成しました"
echo ""
echo "レイアウト:"
echo "   ┌─────────────┬─────────────┬─────────────┐"
echo "   │             │ [1] Foreman │ [2] Miller  │"
echo "   │ [0] Status  ├─────────────┼─────────────┤"
echo "   │             │ [4] Sifter  │ [3] Gleaner │"
echo "   └─────────────┴─────────────┴─────────────┘"
echo ""
echo "接続: tmux attach -t $SESSION_NAME"
echo ""
echo "各職人の起動方法:"
echo "   Miller:  tmux send-keys -t $SESSION_NAME:$WINDOW_NAME.2 'claude --dangerously-skip-permissions' Enter"
echo "   Gleaner: tmux send-keys -t $SESSION_NAME:$WINDOW_NAME.3 'claude --dangerously-skip-permissions' Enter"
echo "   Sifter:  tmux send-keys -t $SESSION_NAME:$WINDOW_NAME.4 'claude --dangerously-skip-permissions' Enter"
echo ""
echo "権限スキップモードで実行中（自動実行）"
echo "   緊急停止: Ctrl+C または ./scripts/stop.sh"
