#!/bin/bash
# update_state.sh - 職人状態ファイル更新スクリプト
# 使用者: 全職人
#
# 使用例:
#   ./scripts/agent/update_state.sh miller working task_xxx
#   ./scripts/agent/update_state.sh miller working task_xxx "実装中"
#   ./scripts/agent/update_state.sh miller idle
#   ./scripts/agent/update_state.sh miller blocked task_xxx "APIエラーで停止"
#   ./scripts/agent/update_state.sh sifter reviewing task_xxx

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: update_state.sh <職人名> <status> [current_task] [progress]

職人の状態ファイル（state/*.yaml）を更新します。

引数:
  職人名        foreman, miller, sifter, gleaner
  status        職人ごとの有効なステータス（下記参照）
  current_task  現在の仕事ID（idle以外の場合に指定）
  progress      現在の進捗状況（任意、作業中/ブロック時に記載推奨）

ステータス一覧:
  foreman:  idle, working, waiting_patron
  miller:   idle, working, blocked
  sifter:   inactive, idle, reviewing
  gleaner:  inactive, idle, researching

例:
  update_state.sh miller working task_20260130_auth "実装開始"
  update_state.sh miller blocked task_20260130_auth "外部API接続エラー"
  update_state.sh miller idle
  update_state.sh sifter reviewing task_20260130_auth "コードレビュー中"
  update_state.sh gleaner researching task_20260130_auth "ライブラリ調査中"
  update_state.sh foreman waiting_patron task_20260130_auth "旦那の判断待ち"

注意:
  - idle/inactive 時は current_task と progress は自動的にクリアされます
  - blocked 時は progress に問題内容を記載することを推奨します
EOF
    exit 0
}

# 引数チェック
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

AGENT="$1"
STATUS="$2"
CURRENT_TASK="${3:-null}"
PROGRESS="${4:-}"

# 職人名検証
case "$AGENT" in
    foreman|miller|sifter|gleaner)
        ;;
    *)
        echo "エラー: 無効な職人名 '$AGENT'"
        echo "有効な職人名: foreman, miller, sifter, gleaner"
        exit 1
        ;;
esac

# ステータス検証（職人ごと）
case "$AGENT" in
    foreman)
        case "$STATUS" in
            idle|working|waiting_patron) ;;
            *)
                echo "エラー: Foremanの無効なステータス '$STATUS'"
                echo "有効なステータス: idle, working, waiting_patron"
                exit 1
                ;;
        esac
        ;;
    miller)
        case "$STATUS" in
            idle|working|blocked) ;;
            *)
                echo "エラー: Millerの無効なステータス '$STATUS'"
                echo "有効なステータス: idle, working, blocked"
                exit 1
                ;;
        esac
        ;;
    sifter)
        case "$STATUS" in
            inactive|idle|reviewing) ;;
            *)
                echo "エラー: Sifterの無効なステータス '$STATUS'"
                echo "有効なステータス: inactive, idle, reviewing"
                exit 1
                ;;
        esac
        ;;
    gleaner)
        case "$STATUS" in
            inactive|idle|researching) ;;
            *)
                echo "エラー: Gleanerの無効なステータス '$STATUS'"
                echo "有効なステータス: inactive, idle, researching"
                exit 1
                ;;
        esac
        ;;
esac

STATE_FILE="$MILL_ROOT/state/${AGENT}.yaml"

# ファイル存在チェック
if [ ! -f "$STATE_FILE" ]; then
    echo "エラー: 状態ファイルが見つかりません: $STATE_FILE"
    exit 1
fi

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# idle系の場合はcurrent_taskとprogressをクリア
if [ "$STATUS" = "idle" ] || [ "$STATUS" = "inactive" ]; then
    CURRENT_TASK="null"
    PROGRESS=""
fi

# progressが空の場合の処理（YAMLで空文字列として保存）
if [ -z "$PROGRESS" ]; then
    PROGRESS_VALUE='""'
else
    PROGRESS_VALUE="\"$PROGRESS\""
fi

# YAMLを更新（sedで各フィールドを更新）
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^status: .*/status: $STATUS/" "$STATE_FILE"
    sed -i '' "s/^current_task: .*/current_task: $CURRENT_TASK/" "$STATE_FILE"
    sed -i '' "s/^progress: .*/progress: $PROGRESS_VALUE/" "$STATE_FILE"
    sed -i '' "s/^last_updated: .*/last_updated: \"$TIMESTAMP\"/" "$STATE_FILE"
else
    # Linux
    sed -i "s/^status: .*/status: $STATUS/" "$STATE_FILE"
    sed -i "s/^current_task: .*/current_task: $CURRENT_TASK/" "$STATE_FILE"
    sed -i "s/^progress: .*/progress: $PROGRESS_VALUE/" "$STATE_FILE"
    sed -i "s/^last_updated: .*/last_updated: \"$TIMESTAMP\"/" "$STATE_FILE"
fi

echo "状態更新完了: $AGENT"
echo "  status: $STATUS"
echo "  current_task: $CURRENT_TASK"
echo "  progress: $PROGRESS"
echo "  last_updated: $TIMESTAMP"
