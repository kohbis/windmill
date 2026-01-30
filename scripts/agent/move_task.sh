#!/bin/bash
# move_task.sh - 仕事ステータス遷移スクリプト
# 使用者: Foreman
#
# 使用例:
#   ./scripts/agent/move_task.sh task_20260130_auth in_progress miller
#   ./scripts/agent/move_task.sh task_20260130_auth completed
#   ./scripts/agent/move_task.sh task_20260130_auth failed

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: move_task.sh <task_id> <to_status> [assigned_to]

仕事を指定したステータスに遷移（移動）します。

引数:
  task_id      仕事ID（例: task_20260130_auth）
  to_status    移動先ステータス: pending, in_progress, completed, failed
  assigned_to  担当者（in_progressの場合必須）: miller, sifter, gleaner

例:
  move_task.sh task_20260130_auth in_progress miller  # Millerに割り当て
  move_task.sh task_20260130_auth completed           # 完了
  move_task.sh task_20260130_auth failed              # 中断/保留
  move_task.sh task_20260130_auth pending             # 待ちに戻す
EOF
    exit 0
}

# 引数チェック
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

TASK_ID="$1"
TO_STATUS="$2"
ASSIGNED_TO="${3:-null}"

# ステータス検証
case "$TO_STATUS" in
    pending|in_progress|completed|failed)
        ;;
    *)
        echo "エラー: 無効なステータス '$TO_STATUS'"
        echo "有効なステータス: pending, in_progress, completed, failed"
        exit 1
        ;;
esac

# in_progressの場合はassigned_toが必要
if [ "$TO_STATUS" = "in_progress" ] && [ "$ASSIGNED_TO" = "null" ]; then
    echo "エラー: in_progressには担当者（assigned_to）が必要です"
    echo "使用方法: move_task.sh $TASK_ID in_progress <miller|sifter|gleaner>"
    exit 1
fi

# タスクファイルを探す
TASK_FILE=""
for dir in pending in_progress completed failed; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        FROM_STATUS="$dir"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "エラー: タスク '$TASK_ID' が見つかりません"
    exit 1
fi

# 同じステータスへの移動は不要
if [ "$FROM_STATUS" = "$TO_STATUS" ]; then
    echo "タスクは既に $TO_STATUS にあります"
    exit 0
fi

# 移動先パス
DEST_FILE="$MILL_ROOT/tasks/$TO_STATUS/${TASK_ID}.yaml"

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# YAMLのstatus更新
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^status: .*/status: $TO_STATUS/" "$TASK_FILE"
    sed -i '' "s/^assigned_to: .*/assigned_to: $ASSIGNED_TO/" "$TASK_FILE"
else
    # Linux
    sed -i "s/^status: .*/status: $TO_STATUS/" "$TASK_FILE"
    sed -i "s/^assigned_to: .*/assigned_to: $ASSIGNED_TO/" "$TASK_FILE"
fi

# completed の場合は completed_at を追加
if [ "$TO_STATUS" = "completed" ]; then
    # completed_atが既にあるかチェック
    if ! grep -q "^completed_at:" "$TASK_FILE"; then
        echo "completed_at: \"$TIMESTAMP\"" >> "$TASK_FILE"
    fi
fi

# ファイル移動
mv "$TASK_FILE" "$DEST_FILE"

echo "移動完了: $FROM_STATUS → $TO_STATUS"
echo "  タスク: $TASK_ID"
echo "  担当: $ASSIGNED_TO"
echo "  ファイル: $DEST_FILE"
