#!/bin/bash
# setup.sh - Windmill 初期セットアップ

set -e

MILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Windmill (風車小屋) セットアップを開始..."

# ディレクトリ作成
echo "ディレクトリを作成中..."
mkdir -p "$MILL_ROOT/tasks/pending"      # 待ち仕事
mkdir -p "$MILL_ROOT/tasks/in_progress"  # 挽き中の仕事
mkdir -p "$MILL_ROOT/tasks/completed"    # 挽き上がり
mkdir -p "$MILL_ROOT/tasks/failed"       # 中断/保留
mkdir -p "$MILL_ROOT/state"              # 職人状態管理
mkdir -p "$MILL_ROOT/scripts"
mkdir -p "$MILL_ROOT/agents/foreman"     # 職人専用ディレクトリ
mkdir -p "$MILL_ROOT/agents/miller"
mkdir -p "$MILL_ROOT/agents/sifter"
mkdir -p "$MILL_ROOT/agents/gleaner"
mkdir -p "$MILL_ROOT/feedback"           # 旦那からの声

# 職人状態ファイル初期化（テンプレートからコピー）
echo "職人状態を初期化中..."

for template in "$MILL_ROOT/state"/*.yaml.template; do
  target="${template%.template}"
  if [ ! -f "$target" ]; then
    cp "$template" "$target"
    echo "  $(basename "$target") を作成しました"
  else
    echo "  $(basename "$target") は既に存在します（スキップ）"
  fi
done

# dashboard.md初期化（テンプレートからコピーしてタイムスタンプ置換）
echo "dashboard.md を初期化中..."
if [ ! -f "$MILL_ROOT/dashboard.md" ]; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
  sed "s/YYYY-MM-DD HH:MM/$TIMESTAMP/g" "$MILL_ROOT/dashboard.md.template" > "$MILL_ROOT/dashboard.md"
  echo "  dashboard.md を作成しました"
else
  echo "  dashboard.md は既に存在します（スキップ）"
fi

# feedback初期化（テンプレートからコピー）
echo "feedback を初期化中..."
for template in "$MILL_ROOT/feedback"/*.md.template; do
  target="${template%.template}"
  if [ ! -f "$target" ]; then
    cp "$template" "$target"
    echo "  $(basename "$target") を作成しました"
  else
    echo "  $(basename "$target") は既に存在します（スキップ）"
  fi
done

# .gitkeep作成（空ディレクトリ保持用）
touch "$MILL_ROOT/tasks/pending/.gitkeep"
touch "$MILL_ROOT/tasks/in_progress/.gitkeep"
touch "$MILL_ROOT/tasks/completed/.gitkeep"
touch "$MILL_ROOT/tasks/failed/.gitkeep"

echo "セットアップ完了!"
echo ""
echo "次のステップ:"
echo "  ./scripts/start.sh  - 職人を起動"
echo "  ./scripts/status.sh - 状況を確認"
