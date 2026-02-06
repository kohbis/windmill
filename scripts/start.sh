#!/bin/bash
# start.sh - Windmill tmuxセッション起動（全職人配置）

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# ヘルプメッセージ
show_help() {
    cat << EOF
使用法: $0 [DEFAULT_AGENT] [OPTIONS]

DEFAULT_AGENT: 全エージェントのデフォルト (claude|codex|copilot)
               デフォルト: claude

OPTIONS:
  --foreman AGENT   Foremanのエージェントを指定
  --miller AGENT    Millerのエージェントを指定
  --gleaner AGENT   Gleanerのエージェントを指定
  --sifter AGENT    Sifterのエージェントを指定
  -h, --help        このヘルプを表示

AGENT: claude|codex|copilot (短縮形: c|x|g)

例:
  $0                              # 全てclaude
  $0 codex                        # 全てcodex
  $0 --gleaner codex              # gleanerのみcodex、他はclaude
  $0 claude --miller copilot      # millerのみcopilot、他はclaude
  $0 codex --gleaner claude --sifter claude  # gleanerとsifterはclaude、他はcodex
EOF
    exit 0
}

# エージェントコマンドを取得する関数
get_agent_cmd() {
    local agent_type="$1"
    case "$agent_type" in
        claude|c)
            echo "claude --dangerously-skip-permissions"
            ;;
        codex|x)
            echo "codex --full-auto"
            ;;
        copilot|g)
            echo "copilot --allow-all"
            ;;
        *)
            echo "不明なエージェント: $agent_type" >&2
            exit 1
            ;;
    esac
}

# エージェント名を取得する関数
get_agent_name() {
    local agent_type="$1"
    case "$agent_type" in
        claude|c) echo "Claude Code" ;;
        codex|x) echo "OpenAI Codex CLI" ;;
        copilot|g) echo "GitHub Copilot CLI" ;;
        *) echo "Unknown" ;;
    esac
}

# デフォルトエージェント: claude
DEFAULT_AGENT="claude"

# 個別エージェント設定（デフォルトは未設定）
FOREMAN_AGENT=""
MILLER_AGENT=""
GLEANER_AGENT=""
SIFTER_AGENT=""

# コマンドライン引数をパース
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
            echo "不明なオプション: $1"
            echo "ヘルプ: $0 --help"
            exit 1
            ;;
        *)
            # 最初の位置引数をデフォルトエージェントとして扱う
            if [[ -z "$DEFAULT_AGENT" || "$DEFAULT_AGENT" == "claude" ]]; then
                DEFAULT_AGENT="$1"
            else
                echo "複数のデフォルトエージェントが指定されています: $DEFAULT_AGENT と $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# 個別指定がなければデフォルトを使用
FOREMAN_AGENT="${FOREMAN_AGENT:-$DEFAULT_AGENT}"
MILLER_AGENT="${MILLER_AGENT:-$DEFAULT_AGENT}"
GLEANER_AGENT="${GLEANER_AGENT:-$DEFAULT_AGENT}"
SIFTER_AGENT="${SIFTER_AGENT:-$DEFAULT_AGENT}"

# 各エージェントのコマンドを取得
FOREMAN_CMD=$(get_agent_cmd "$FOREMAN_AGENT")
MILLER_CMD=$(get_agent_cmd "$MILLER_AGENT")
GLEANER_CMD=$(get_agent_cmd "$GLEANER_AGENT")
SIFTER_CMD=$(get_agent_cmd "$SIFTER_AGENT")

echo "エージェント設定:"
echo "  Foreman: $(get_agent_name "$FOREMAN_AGENT")"
echo "  Miller:  $(get_agent_name "$MILLER_AGENT")"
echo "  Gleaner: $(get_agent_name "$GLEANER_AGENT")"
echo "  Sifter:  $(get_agent_name "$SIFTER_AGENT")"
echo ""

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
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" "$FOREMAN_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.1" Enter
sleep 0.2

# Miller (ペイン2)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" "$MILLER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.2" Enter
sleep 0.2

# Gleaner (ペイン3)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" "$GLEANER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.3" Enter
sleep 0.2

# Sifter (ペイン4)
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" "$SIFTER_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.4" Enter
sleep 0.2

# Foremanペインを選択
tmux select-pane -t "$SESSION_NAME:$WINDOW_NAME.1"

echo "tmuxセッション '$SESSION_NAME' を作成しました"
echo ""
echo "エージェント構成:"
echo "  [1] Foreman: $(get_agent_name "$FOREMAN_AGENT")"
echo "  [2] Miller:  $(get_agent_name "$MILLER_AGENT")"
echo "  [3] Gleaner: $(get_agent_name "$GLEANER_AGENT")"
echo "  [4] Sifter:  $(get_agent_name "$SIFTER_AGENT")"
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
