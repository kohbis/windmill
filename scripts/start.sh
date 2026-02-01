#!/bin/bash
# start.sh - Windmill tmuxセッション起動（全職人配置）

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# デフォルトエージェント: claude
AGENT_TYPE="${1:-claude}"

# エージェントコマンドの設定
case "$AGENT_TYPE" in
    claude|c)
        AGENT_CMD="claude --dangerously-skip-permissions"
        AGENT_NAME="Claude Code"
        ;;
    codex|x)
        AGENT_CMD="codex --full-auto"
        AGENT_NAME="OpenAI Codex CLI"
        ;;
    copilot|g)
        AGENT_CMD="copilot --allow-all"
        AGENT_NAME="GitHub Copilot CLI"
        ;;
    *)
        echo "不明なエージェント: $AGENT_TYPE"
        echo "使用法: $0 [claude|codex|copilot]"
        exit 1
        ;;
esac

echo "エージェント: $AGENT_NAME"
echo ""

# 既存セッションチェック
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "  セッション '$SESSION_NAME' は既に存在します"
    echo "   接続: tmux attach -t $SESSION_NAME"
    echo "   停止: ./scripts/stop.sh"
    exit 1
fi

echo "Windmill (風車小屋) を起動中..."

# 状態ファイルをテンプレートから初期化
echo "状態ファイルを初期化中..."
for agent in foreman miller sifter gleaner; do
    if [ -f "$MILL_ROOT/state/${agent}.yaml.template" ]; then
        cp "$MILL_ROOT/state/${agent}.yaml.template" "$MILL_ROOT/state/${agent}.yaml"
    fi
done

# ダッシュボードをテンプレートから初期化
if [ -f "$MILL_ROOT/dashboard.md.template" ]; then
    cp "$MILL_ROOT/dashboard.md.template" "$MILL_ROOT/dashboard.md"
    # 最終更新とセットアップ完了のタイムスタンプを設定
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/YYYY-MM-DD HH:MM/$TIMESTAMP/g" "$MILL_ROOT/dashboard.md"
    else
        sed -i "s/YYYY-MM-DD HH:MM/$TIMESTAMP/g" "$MILL_ROOT/dashboard.md"
    fi
fi

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

echo "職人準備中..."

# Status監視を起動（左ペイン）
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.0" "watch -n 5 ./scripts/status.sh" Enter

# 全職人を自動起動
sleep 0.3

# Foreman (ペイン1)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" Enter
sleep 0.2

# Miller (ペイン2)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" Enter
sleep 0.2

# Gleaner (ペイン3)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" Enter
sleep 0.2

# Sifter (ペイン4)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "$AGENT_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" Enter
sleep 0.2

# Foremanペインを選択
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1"

echo "tmuxセッション '$SESSION_NAME' を作成しました"
echo ""
echo "エージェント: $AGENT_NAME"
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
echo "職人たちが持ち場につきました"
echo "   緊急停止: Ctrl+C または ./scripts/stop.sh"
