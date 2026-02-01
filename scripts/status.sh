#!/bin/bash
# status.sh - Windmill 状況表示

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# YAMLから値を取得する簡易関数（コメント除去）
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/  *#.*//' | tr -d '"'
}

echo "═══════════════════════════════════════════════════════════"
echo "  WINDMILL STATUS - $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 職人状態
echo "【職人状態】"
echo "───────────────────────────────────────────────────────────"

# Foreman
foreman_status=$(get_yaml_value "$MILL_ROOT/state/foreman.yaml" "status")
foreman_task=$(get_yaml_value "$MILL_ROOT/state/foreman.yaml" "current_task")
[[ "$foreman_task" == "null" ]] && foreman_task=""
printf "  %-12s │ %-10s │ %s\n" "Foreman" "${foreman_status:-unknown}" "${foreman_task:-なし}"

# Miller
miller_status=$(get_yaml_value "$MILL_ROOT/state/miller.yaml" "status")
miller_task=$(get_yaml_value "$MILL_ROOT/state/miller.yaml" "current_task")
[[ "$miller_task" == "null" ]] && miller_task=""
printf "  %-12s │ %-10s │ %s\n" "Miller" "${miller_status:-unknown}" "${miller_task:-なし}"

# Sifter
sifter_status=$(get_yaml_value "$MILL_ROOT/state/sifter.yaml" "status")
sifter_task=$(get_yaml_value "$MILL_ROOT/state/sifter.yaml" "current_task")
[[ "$sifter_task" == "null" ]] && sifter_task=""
printf "  %-12s │ %-10s │ %s\n" "Sifter" "${sifter_status:-inactive}" "${sifter_task:-なし}"

# Gleaner
gleaner_status=$(get_yaml_value "$MILL_ROOT/state/gleaner.yaml" "status")
gleaner_task=$(get_yaml_value "$MILL_ROOT/state/gleaner.yaml" "current_task")
[[ "$gleaner_task" == "null" ]] && gleaner_task=""
printf "  %-12s │ %-10s │ %s\n" "Gleaner" "${gleaner_status:-inactive}" "${gleaner_task:-なし}"

echo ""

# 仕事キュー状態
echo "【仕事キュー】"
echo "───────────────────────────────────────────────────────────"

pending_count=$(find "$MILL_ROOT/tasks/pending" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
in_progress_count=$(find "$MILL_ROOT/tasks/in_progress" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
completed_count=$(find "$MILL_ROOT/tasks/completed" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
failed_count=$(find "$MILL_ROOT/tasks/failed" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

printf "  %-15s │ %3d 件  (待ち仕事)\n" "pending/" "$pending_count"
printf "  %-15s │ %3d 件  (挽き中の仕事)\n" "in_progress/" "$in_progress_count"
printf "  %-15s │ %3d 件  (挽き上がり)\n" "completed/" "$completed_count"
printf "  %-15s │ %3d 件  (中断/保留)\n" "failed/" "$failed_count"

echo ""

# 挽き中の仕事詳細
if [ "$in_progress_count" -gt 0 ]; then
    echo "【挽き中の仕事詳細】"
    echo "───────────────────────────────────────────────────────────"
    for task_file in "$MILL_ROOT/tasks/in_progress"/*.yaml; do
        if [ -f "$task_file" ]; then
            task_id=$(get_yaml_value "$task_file" "id")
            task_title=$(get_yaml_value "$task_file" "title")
            task_status=$(get_yaml_value "$task_file" "status")
            assigned=$(get_yaml_value "$task_file" "assigned_to")
            printf "  %s: %s\n" "$task_id" "$task_title"
            printf "    状態: %s  担当: %s\n" "$task_status" "${assigned:-未割当}"
        fi
    done
    echo ""
fi

# ダッシュボード表示
if [ -f "$MILL_ROOT/dashboard.md" ]; then
    echo "【ダッシュボード】"
    echo "───────────────────────────────────────────────────────────"
    # 最初の20行を表示（ヘッダー除去）
    head -20 "$MILL_ROOT/dashboard.md" | tail -n +2
    echo ""
fi

echo "═══════════════════════════════════════════════════════════"
