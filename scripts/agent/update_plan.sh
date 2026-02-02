#!/bin/bash
# update_plan.sh - 仕事YAMLに実装計画を追記するスクリプト
# 使用者: Foreman（Gleanerからの計画報告を受けて使用）
#
# 使用例:
#   ./scripts/agent/update_plan.sh task_20260130_auth "React" "軽量で実績あり" "小規模"
#   ./scripts/agent/update_plan.sh --approve task_20260130_auth

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: update_plan.sh [オプション] <task_id> [計画情報...]

仕事YAMLに実装計画を追記、または旦那許可を記録します。

モード1: 計画追記
  update_plan.sh <task_id> "<tech>" "<reason>" "<size>" ["<step1>" "<step2>"...] ["--risk" "<risk1>" "<risk2>"...]

モード2: 旦那許可記録
  update_plan.sh --approve <task_id>

オプション:
  --approve       旦那許可を記録し、statusをpendingに変更
  --arch <text>   アーキテクチャの説明
  --risk <risks>  リスク・懸念点（複数指定可）
  -h, --help      このヘルプを表示

サイズ:
  small   - 小規模（単一ファイル、簡単な変更）
  medium  - 中規模（複数ファイル、標準的な実装）
  large   - 大規模（多数ファイル、複雑な実装）

例:
  # 計画追記
  update_plan.sh task_20260130_auth "lodash" "軽量で実績あり" "small" "util作成" "テスト追加"
  
  # リスク付き
  update_plan.sh task_20260130_auth "React" "標準的" "medium" "コンポーネント作成" --risk "既存CSSとの競合" "IE非対応"
  
  # 旦那許可
  update_plan.sh --approve task_20260130_auth
EOF
    exit 0
}

# 引数解析
APPROVE_MODE=false
ARCHITECTURE=""
RISKS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --approve)
            APPROVE_MODE=true
            shift
            ;;
        --arch)
            ARCHITECTURE="$2"
            shift 2
            ;;
        --risk)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                RISKS+=("$1")
                shift
            done
            ;;
        -h|--help)
            show_help
            ;;
        *)
            break
            ;;
    esac
done

# タスクID取得
if [ $# -lt 1 ]; then
    echo "エラー: タスクIDが必要です"
    show_help
fi

TASK_ID="$1"
shift

# タスクファイル検索
TASK_FILE=""
for dir in pending in_progress; do
    if [ -f "$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml" ]; then
        TASK_FILE="$MILL_ROOT/tasks/$dir/${TASK_ID}.yaml"
        break
    fi
done

if [ -z "$TASK_FILE" ]; then
    echo "エラー: タスクファイルが見つかりません: $TASK_ID"
    echo "tasks/pending/ または tasks/in_progress/ を確認してください"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 旦那許可モード
if [ "$APPROVE_MODE" = true ]; then
    # plan セクションの patron_approved を更新
    if grep -q "patron_approved:" "$TASK_FILE"; then
        sed -i.bak "s/patron_approved: false/patron_approved: true/" "$TASK_FILE"
        sed -i.bak "s/approved_at: null/approved_at: \"$TIMESTAMP\"/" "$TASK_FILE"
    else
        # plan セクションがない場合は追記
        cat >> "$TASK_FILE" << EOF

# 旦那許可
patron_approved: true
approved_at: "$TIMESTAMP"
EOF
    fi
    
    # status を pending に変更
    sed -i.bak "s/status: planning/status: pending/" "$TASK_FILE"
    
    # バックアップ削除
    rm -f "${TASK_FILE}.bak"
    
    echo "旦那許可を記録: $TASK_FILE"
    echo "ステータス: pending（実装開始可能）"
    echo ""
    echo "次のステップ: Miller に実装指示を送信"
    echo "  move_task.sh $TASK_ID in_progress miller"
    echo "  send_to.sh miller \"$TASK_FILE を処理してください\""
    exit 0
fi

# 計画追記モード
if [ $# -lt 3 ]; then
    echo "エラー: 計画追記には tech, reason, size が必要です"
    echo "使用方法: update_plan.sh <task_id> \"<tech>\" \"<reason>\" \"<size>\" [steps...]"
    exit 1
fi

TECH="$1"
REASON="$2"
SIZE="$3"
shift 3

# 残りは実装ステップ
IMPL_STEPS=()
while [[ $# -gt 0 && "$1" != "--risk" ]]; do
    IMPL_STEPS+=("$1")
    shift
done

# --risk が来たらリスク収集
if [[ "$1" == "--risk" ]]; then
    shift
    while [[ $# -gt 0 ]]; do
        RISKS+=("$1")
        shift
    done
fi

# 既存のコメントアウトされた plan セクションを削除
sed -i.bak '/^# --- 実装計画/,/^#   approved_at:/d' "$TASK_FILE"

# plan セクションを追記
cat >> "$TASK_FILE" << EOF

# --- 実装計画（Gleaner との計画策定結果） ---
plan:
  tech_selection: "$TECH"
  tech_reason: |
    $REASON
EOF

# アーキテクチャ
if [ -n "$ARCHITECTURE" ]; then
    cat >> "$TASK_FILE" << EOF
  architecture: |
    $ARCHITECTURE
EOF
else
    cat >> "$TASK_FILE" << EOF
  architecture: null
EOF
fi

# 実装ステップ
echo "  implementation_steps:" >> "$TASK_FILE"
if [ ${#IMPL_STEPS[@]} -gt 0 ]; then
    for step in "${IMPL_STEPS[@]}"; do
        echo "    - \"$step\"" >> "$TASK_FILE"
    done
else
    echo "    - \"（ステップ未定義）\"" >> "$TASK_FILE"
fi

# リスク
echo "  risks:" >> "$TASK_FILE"
if [ ${#RISKS[@]} -gt 0 ]; then
    for risk in "${RISKS[@]}"; do
        echo "    - \"$risk\"" >> "$TASK_FILE"
    done
else
    echo "    - null" >> "$TASK_FILE"
fi

# メタ情報
cat >> "$TASK_FILE" << EOF
  estimated_size: $SIZE
  planned_by: gleaner
  planned_at: "$TIMESTAMP"
  patron_approved: false
  approved_at: null
EOF

# バックアップ削除
rm -f "${TASK_FILE}.bak"

echo "計画を追記: $TASK_FILE"
echo ""
echo "次のステップ: 旦那に計画を報告し、許可を得る"
echo "許可が出たら: update_plan.sh --approve $TASK_ID"
