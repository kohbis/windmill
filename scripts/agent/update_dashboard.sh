#!/bin/bash
# update_dashboard.sh - ダッシュボード自動更新スクリプト
# 使用者: Foreman
#
# 使用例:
#   ./scripts/agent/update_dashboard.sh
#   ./scripts/agent/update_dashboard.sh --log "Millerに指示送信"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DASHBOARD="$MILL_ROOT/dashboard.md"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: update_dashboard.sh [オプション]

ダッシュボード（dashboard.md）を仕事キューの状態から自動更新します。

オプション:
  --log "<メッセージ>"  作業ログにエントリを追加
  -h, --help           このヘルプを表示

例:
  update_dashboard.sh                         # 全体を更新
  update_dashboard.sh --log "Millerに指示送信"  # ログ追記のみ
EOF
    exit 0
}

# YAMLから値を取得する簡易関数
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/  *#.*//' | tr -d '"'
}

# 引数解析
LOG_MESSAGE=""
LOG_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log)
            LOG_MESSAGE="$2"
            LOG_ONLY=true
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "エラー: 不明なオプション '$1'"
            show_help
            ;;
    esac
done

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
TIME_ONLY=$(date '+%H:%M')

# ログ追記のみの場合
if [ "$LOG_ONLY" = true ] && [ -n "$LOG_MESSAGE" ]; then
    if [ -f "$DASHBOARD" ]; then
        # 作業ログセクションの末尾に追記
        echo "- $TIMESTAMP $LOG_MESSAGE" >> "$DASHBOARD"
        
        # 最終更新も更新
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^最終更新: .*/最終更新: $TIMESTAMP/" "$DASHBOARD"
        else
            sed -i "s/^最終更新: .*/最終更新: $TIMESTAMP/" "$DASHBOARD"
        fi
        
        echo "作業ログ追記完了: $LOG_MESSAGE"
    else
        echo "エラー: dashboard.md が見つかりません"
        exit 1
    fi
    exit 0
fi

# 全体更新
# 進行中の仕事を収集
IN_PROGRESS=""
for task_file in "$MILL_ROOT/tasks/in_progress"/*.yaml; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        assigned=$(get_yaml_value "$task_file" "assigned_to")
        [[ "$assigned" == "null" ]] && assigned="未割当"
        IN_PROGRESS="${IN_PROGRESS}- [ ] ${task_id}: ${task_title} (${assigned}担当)\n"
    fi
done
[ -z "$IN_PROGRESS" ] && IN_PROGRESS="（なし）\n"

# 完了した仕事を収集（最新5件）
COMPLETED=""
completed_files=$(ls -t "$MILL_ROOT/tasks/completed"/*.yaml 2>/dev/null | head -5)
for task_file in $completed_files; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        COMPLETED="${COMPLETED}- [x] ${task_id}: ${task_title}\n"
    fi
done
[ -z "$COMPLETED" ] && COMPLETED="（なし）\n"

# 待ち仕事を収集
PENDING=""
for task_file in "$MILL_ROOT/tasks/pending"/*.yaml; do
    if [ -f "$task_file" ]; then
        task_id=$(get_yaml_value "$task_file" "id")
        task_title=$(get_yaml_value "$task_file" "title")
        PENDING="${PENDING}- ${task_id}: ${task_title}\n"
    fi
done

# 既存の作業ログを保持
EXISTING_LOG=""
if [ -f "$DASHBOARD" ]; then
    EXISTING_LOG=$(awk '/^## 作業ログ/,0 { if (!/^## 作業ログ/) print }' "$DASHBOARD")
fi
[ -z "$EXISTING_LOG" ] && EXISTING_LOG="- $TIME_ONLY ダッシュボード更新"

# 要対応セクション
NEEDS_ACTION="（なし）"
if [ -n "$PENDING" ]; then
    NEEDS_ACTION="待ち仕事あり:\n${PENDING}"
fi

# ダッシュボード生成
cat > "$DASHBOARD" << EOF
# Windmill Dashboard
最終更新: $TIMESTAMP

## 進行中
$(echo -e "$IN_PROGRESS" | sed 's/\\n$//')

## 完了
$(echo -e "$COMPLETED" | sed 's/\\n$//')

## 要対応（旦那の判断待ち）
$(echo -e "$NEEDS_ACTION" | sed 's/\\n$//')

## 作業ログ
$EXISTING_LOG
EOF

echo "ダッシュボード更新完了: $DASHBOARD"
