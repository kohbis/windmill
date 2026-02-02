#!/bin/bash
# create_task.sh - 仕事YAML作成スクリプト
# 使用者: Foreman
#
# 使用例:
#   ./scripts/agent/create_task.sh "認証機能の実装" "ステップ1" "ステップ2" "ステップ3"
#   ./scripts/agent/create_task.sh --id custom_id "タイトル" "ステップ1"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_FILE="$MILL_ROOT/tasks/task.yaml.template"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: create_task.sh [オプション] "<タイトル>" "<ステップ1>" [<ステップ2>...]

仕事YAMLを tasks/pending/ に作成します。
テンプレート: tasks/task.yaml.template を使用

オプション:
  --id <id>       カスタムIDを指定（デフォルト: task_YYYYMMDD_<slug>）
  --context <text> コンテキスト情報を追加
  --status <status> 初期ステータス（デフォルト: planning）
  -h, --help      このヘルプを表示

ステータス:
  planning    - 計画策定中（Gleaner との計画策定待ち）
  pending     - 計画確定、実装待ち（旦那許可済み）

例:
  create_task.sh "認証機能の実装" "ログイン画面作成" "API連携" "テスト追加"
  create_task.sh --id task_20260130_auth "認証機能" "ステップ1"
  create_task.sh --context "前回の続き" "バグ修正" "原因調査" "修正実装"
  create_task.sh --status pending "簡単な修正" "typo修正"
EOF
    exit 0
}

# 引数解析
CUSTOM_ID=""
CONTEXT=""
INITIAL_STATUS="planning"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)
            CUSTOM_ID="$2"
            shift 2
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        --status)
            INITIAL_STATUS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            break
            ;;
    esac
done

# 最低限の引数チェック
if [ $# -lt 2 ]; then
    echo "エラー: タイトルと最低1つのステップが必要です"
    echo "使用方法: create_task.sh \"<タイトル>\" \"<ステップ1>\" [<ステップ2>...]"
    exit 1
fi

TITLE="$1"
shift
STEPS=("$@")

# ID生成
if [ -n "$CUSTOM_ID" ]; then
    TASK_ID="$CUSTOM_ID"
else
    # タイトルからslugを生成（簡易版：最初の単語をローマ字/英語で）
    DATE_PART=$(date '+%Y%m%d')
    # タイトルの最初の20文字を使用し、スペースをアンダースコアに
    SLUG=$(echo "$TITLE" | cut -c1-20 | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_]//g' | tr '[:upper:]' '[:lower:]')
    if [ -z "$SLUG" ]; then
        SLUG="task"
    fi
    TASK_ID="task_${DATE_PART}_${SLUG}"
fi

TASK_FILE="$MILL_ROOT/tasks/pending/${TASK_ID}.yaml"

# 既存チェック
if [ -f "$TASK_FILE" ]; then
    echo "エラー: $TASK_FILE は既に存在します"
    exit 1
fi

# テンプレートチェック
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "エラー: テンプレートファイルが見つかりません: $TEMPLATE_FILE"
    echo "setup.sh を実行してください"
    exit 1
fi

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# テンプレートからYAML生成（コメント行を除く基本部分のみ）
cat > "$TASK_FILE" << EOF
id: $TASK_ID
title: "$TITLE"
status: $INITIAL_STATUS
assigned_to: null
patron_input_required: false
breakdown:
EOF

# ステップ追加
STEP_NUM=1
for step in "${STEPS[@]}"; do
    echo "  - step${STEP_NUM}: \"$step\"" >> "$TASK_FILE"
    ((STEP_NUM++))
done

# planセクション（コメントとして追加、後でGleanerとの計画策定時に有効化）
cat >> "$TASK_FILE" << 'EOF'

# --- 実装計画（Gleaner との計画策定後に追記） ---
# plan:
#   tech_selection: ""
#   tech_reason: |
#     
#   architecture: |
#     
#   implementation_steps:
#     - ""
#   risks:
#     - ""
#   estimated_size: medium
#   planned_by: gleaner
#   planned_at: ""
#   patron_approved: false
#   approved_at: null
EOF

# コンテキスト追加（オプション）
if [ -n "$CONTEXT" ]; then
    cat >> "$TASK_FILE" << EOF

context: |
  $CONTEXT
EOF
fi

# work_logとcreated_at
cat >> "$TASK_FILE" << EOF

work_log: []
created_at: "$TIMESTAMP"
EOF

echo "作成完了: $TASK_FILE"
echo "ID: $TASK_ID"
echo "ステータス: $INITIAL_STATUS"
if [ "$INITIAL_STATUS" = "planning" ]; then
    echo ""
    echo "次のステップ: Gleaner に計画持ち込みを送信してください"
    echo "  send_to.sh gleaner \"【計画持ち込み】${TASK_ID}: ...\""
fi
