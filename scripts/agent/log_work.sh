#!/bin/bash
# log_work.sh - 仕事YAMLのwork_log追記スクリプト
# 使用者: Foreman, Miller
#
# 使用例:
#   ./scripts/agent/log_work.sh task_xxx "実装開始"
#   ./scripts/agent/log_work.sh task_xxx "挽き上がり" "全テストパス"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: log_work.sh <task_id> "<action>" ["<details>"]

仕事YAMLのwork_logにエントリを追記します。

引数:
  task_id   仕事ID（例: task_20260130_auth）
  action    作業内容の説明（必須）
  details   詳細情報（オプション）

例:
  log_work.sh task_20260130_auth "実装開始"
  log_work.sh task_20260130_auth "挽き上がり" "全テストパス"
  log_work.sh task_20260130_auth "レビュー指摘対応" "変数名を修正"
  log_work.sh task_20260130_auth "手詰まり" "依存ライブラリのバージョン問題"
EOF
    exit 0
}

# 引数チェック
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
ACTION="$2"
DETAILS="${3:-}"

# タスクファイルを探す
TASK_FILE=""
for dir in pending in_progress completed failed; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "エラー: タスク '$TASK_ID' が見つかりません"
    exit 1
fi

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# work_logエントリを作成
if [ -n "$DETAILS" ]; then
    LOG_ENTRY="  - timestamp: \"$TIMESTAMP\"
    action: \"$ACTION\"
    details: \"$DETAILS\""
else
    LOG_ENTRY="  - timestamp: \"$TIMESTAMP\"
    action: \"$ACTION\""
fi

# work_log: [] の場合（空の配列）を検出して置換
if grep -q "^work_log: \[\]" "$TASK_FILE"; then
    # 空の配列を展開形式に変換
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^work_log: \[\]/work_log:\n$LOG_ENTRY/" "$TASK_FILE"
    else
        sed -i "s/^work_log: \[\]/work_log:\n$LOG_ENTRY/" "$TASK_FILE"
    fi
else
    # 既存のwork_logに追記
    # work_log:の次の行に追記（awkを使用）
    TEMP_FILE=$(mktemp)
    awk -v entry="$LOG_ENTRY" '
        /^work_log:/ {
            print
            print entry
            next
        }
        { print }
    ' "$TASK_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$TASK_FILE"
fi

echo "work_log追記完了: $TASK_ID"
echo "  timestamp: $TIMESTAMP"
echo "  action: $ACTION"
if [ -n "$DETAILS" ]; then
    echo "  details: $DETAILS"
fi
