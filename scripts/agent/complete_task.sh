#!/bin/bash
# complete_task.sh - 仕事完了レポート追記スクリプト
# 使用者: Foreman
#
# 使用例:
#   ./scripts/agent/complete_task.sh task_xxx "実装完了の概要" "passed"
#   ./scripts/agent/complete_task.sh task_xxx "バグ修正完了" "passed" "追加の最適化推奨"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: complete_task.sh <task_id> "<summary>" "<test_status>" ["<notes>"]

仕事YAMLに完了レポート（resultセクション）を追記し、completedに移動します。

引数:
  task_id       仕事ID（例: task_20260130_auth）
  summary       作業概要（必須）
  test_status   テスト結果: passed, failed, skipped
  notes         補足事項（オプション）

例:
  complete_task.sh task_20260130_auth "認証機能を実装" "passed"
  complete_task.sh task_20260130_auth "バグ修正" "passed" "追加の最適化推奨"
  complete_task.sh task_20260130_auth "調査完了" "skipped" "テスト対象外"
EOF
    exit 0
}

# 引数チェック
if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
SUMMARY="$2"
TEST_STATUS="$3"
NOTES="${4:-}"

# テストステータス検証
case "$TEST_STATUS" in
    passed|failed|skipped)
        ;;
    *)
        echo "エラー: 無効なテストステータス '$TEST_STATUS'"
        echo "有効なステータス: passed, failed, skipped"
        exit 1
        ;;
esac

# タスクファイルを探す（in_progressを優先）
TASK_FILE=""
for dir in in_progress pending; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        FROM_DIR="$dir"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "エラー: タスク '$TASK_ID' が見つかりません（in_progress または pending）"
    exit 1
fi

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# assigned_toを取得
ASSIGNED_TO=$(grep "^assigned_to:" "$TASK_FILE" | sed 's/^assigned_to: *//' | tr -d '"')
[ "$ASSIGNED_TO" = "null" ] && ASSIGNED_TO="miller"

# 既にcompleted_atがあるかチェック
if grep -q "^completed_at:" "$TASK_FILE"; then
    echo "警告: このタスクは既に完了レポートが追記されています"
    echo "上書きせずに移動のみ行います"
else
    # 完了レポートを追記
    cat >> "$TASK_FILE" << EOF

# --- 完了レポート ---
completed_at: "$TIMESTAMP"
completed_by: $ASSIGNED_TO
result:
  summary: |
    $SUMMARY
  tests:
    status: $TEST_STATUS
EOF

    # notesがある場合は追加
    if [ -n "$NOTES" ]; then
        cat >> "$TASK_FILE" << EOF
  notes: |
    $NOTES
EOF
    fi
fi

# statusをcompletedに更新
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^status: .*/status: completed/" "$TASK_FILE"
else
    sed -i "s/^status: .*/status: completed/" "$TASK_FILE"
fi

# completedディレクトリに移動
DEST_FILE="$MILL_ROOT/tasks/completed/${TASK_ID}.yaml"
mv "$TASK_FILE" "$DEST_FILE"

echo "完了処理完了: $TASK_ID"
echo "  概要: $SUMMARY"
echo "  テスト: $TEST_STATUS"
echo "  完了者: $ASSIGNED_TO"
echo "  移動: $FROM_DIR → completed"
echo "  ファイル: $DEST_FILE"
