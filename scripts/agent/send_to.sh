#!/bin/bash
# send_to.sh - 職人への指示送信スクリプト
# 使用者: 全職人
#
# 使用例:
#   ./scripts/agent/send_to.sh miller "tasks/in_progress/task_xxx.yaml を処理してください"
#   ./scripts/agent/send_to.sh foreman "[MILLER:DONE] task_xxx 挽き上がり"

set -e

SESSION_NAME="windmill"
WINDOW_NAME="windmill"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: send_to.sh <職人名> "<メッセージ>"

指定した職人のtmuxペインにメッセージを送信します。
tmux send-keysの2分割ルールを自動で適用します。

職人名:
  foreman  - 親方 (ペイン1)
  miller   - 挽き手 (ペイン2)
  gleaner  - 聞き役 (ペイン3)
  sifter   - 目利き (ペイン4)
  status   - ステータス画面 (ペイン0)

例:
  send_to.sh miller "tasks/in_progress/task_xxx.yaml を処理してください"
  send_to.sh foreman "[MILLER:DONE] task_xxx 挽き上がり"
  send_to.sh gleaner "【調査持ち込み】task_xxx: Reactの状態管理について調べてください"
  send_to.sh sifter "【レビュー持ち込み】task_xxx: src/auth.jsを見てください"
EOF
    exit 0
}

# 引数チェック
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TARGET="$1"
MESSAGE="$2"

# 職人名からペイン番号を取得
case "$TARGET" in
    status)
        PANE=0
        ;;
    foreman)
        PANE=1
        ;;
    miller)
        PANE=2
        ;;
    gleaner)
        PANE=3
        ;;
    sifter)
        PANE=4
        ;;
    *)
        echo "エラー: 無効な職人名 '$TARGET'"
        echo "有効な職人名: foreman, miller, gleaner, sifter, status"
        exit 1
        ;;
esac

# tmuxセッション存在チェック
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "エラー: tmuxセッション '$SESSION_NAME' が存在しません"
    echo "先に ./scripts/start.sh を実行してください"
    exit 1
fi

# メッセージ送信（2分割ルール適用）
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.$PANE" "$MESSAGE"
tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME.$PANE" Enter

echo "送信完了: $TARGET (ペイン$PANE)"
echo "  メッセージ: $MESSAGE"
