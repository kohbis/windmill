# Windmill - 風車小屋マルチエージェント環境

## 概要

Windmill（風車小屋）は、複数のAIコーディングエージェントが協調して作業するマルチエージェント開発環境です。

**対応AIエージェント:**
- Claude Code (Anthropic) - `CLAUDE.md` / `AGENTS.md`
- OpenAI Codex CLI - `AGENTS.md`- GitHub Copilot CLI - `AGENTS.md` / `.github/copilot-instructions.md`
**メタファー**:
- 入力（穀物）: 旦那からの持ち込み・仕事
- 処理（製粉）: 職人たちによる開発作業
- 出力（粉）: 挽き上がったコード・成果物

## 職人構成

| 役割 | 英名 | 責務 | 稼働 |
|------|------|------|------|
| 親方 | Foreman | 仕事の分解、進捗監視、旦那との対話<br>**実装作業は一切行わない** | 常時 |
| 挽き手 | Miller | メインのコーディング・実装作業<br>**親方からの指示でのみ動く** | 常時 |
| 目利き | Sifter | コードレビュー、品質チェック | オンデマンド |
| 聞き役 | Gleaner | 調査、情報収集 | オンデマンド |

### 役割分担の原則

| 職人 | できること | 禁止事項 |
|-------------|----------|----------|
| **Foreman（親方）** | ・仕事管理<br>・進捗監視<br>・職人起動<br>・旦那対話 | ・実装作業<br>・調査作業<br>・レビュー作業 |
| **Miller（挽き手）** | ・コーディング<br>・テスト実行<br>・実装作業 | ・仕事管理<br>・調査作業<br>・レビュー作業<br>・Gleaner/Sifter起動 |
| **Sifter（目利き）** | ・コードレビュー<br>・品質チェック | ・実装作業<br>・調査作業<br>・仕事管理 |
| **Gleaner（聞き役）** | ・技術調査<br>・情報収集 | ・実装作業<br>・レビュー作業<br>・仕事管理 |

### 重要な制約

1. **Gleaner/Sifterの起動はForemanのみが行う**
2. **各職人は自分の専門領域のみ担当し、他の領域には介入しない**
3. **Millerが調査/レビューが必要と判断したら、Foremanに報告して判断を仰ぐ**
4. **すべての報告はForemanを経由する**（職人間の直接通信禁止）

## ディレクトリ構造

```
grist/
├── tasks/                     # 仕事管理
│   ├── pending/               # 待ち仕事
│   ├── in_progress/           # 挽き中の仕事
│   ├── completed/             # 挽き上がり（完了報告含む）
│   └── failed/                # 中断/保留
├── state/                     # 職人状態管理
│   ├── foreman.yaml
│   ├── miller.yaml
│   ├── sifter.yaml
│   └── gleaner.yaml
├── agents/                    # 職人専用ディレクトリ
│   ├── foreman/CLAUDE.md      # 親方のプロンプト
│   ├── miller/CLAUDE.md       # 挽き手のプロンプト
│   ├── sifter/CLAUDE.md       # 目利きのプロンプト
│   └── gleaner/CLAUDE.md      # 聞き役のプロンプト
├── scripts/                   # 操作スクリプト
├── dashboard.md               # 進捗管理（Foremanが更新）

└── feedback/                  # 旦那からの声
    ├── inbox.md               # 未対応フィードバック
    └── archive.md             # 対応済みフィードバック
```

## エージェント用スクリプト

`scripts/agent/` にエージェント（職人）が使用するスクリプトを配置しています。
これらはトークン効率化と再現性向上のために作成されました。

| スクリプト | 使用者 | 用途 |
|-----------|--------|------|
| `create_task.sh` | Foreman | 仕事YAML作成 |
| `move_task.sh` | Foreman | 仕事ステータス遷移（pending→in_progress→completed/failed） |
| `send_to.sh` | 全職人 | 職人への指示送信（tmux send-keysのラッパー） |
| `update_state.sh` | 全職人 | 職人状態ファイル（state/*.yaml）の更新 |
| `log_work.sh` | Foreman, Miller | 仕事YAMLのwork_log追記 |
| `update_dashboard.sh` | Foreman | ダッシュボード自動更新・作業ログ追記 |
| `complete_task.sh` | Foreman | 仕事完了レポート追記＋completedへ移動 |

### 使用例

```bash
# 仕事YAML作成
./scripts/agent/create_task.sh "認証機能の実装" "ステップ1" "ステップ2"

# 仕事をMillerに割り当て
./scripts/agent/move_task.sh task_20260130_auth in_progress miller

# Millerに指示を送る
./scripts/agent/send_to.sh miller "tasks/in_progress/task_20260130_auth.yaml を処理してください"

# 仕事を完了
./scripts/agent/move_task.sh task_20260130_auth completed
```

```bash
# 職人状態を更新
./scripts/agent/update_state.sh miller working task_20260130_auth
./scripts/agent/update_state.sh miller idle

# work_logに追記
./scripts/agent/log_work.sh task_20260130_auth "実装開始"
./scripts/agent/log_work.sh task_20260130_auth "挝き上がり" "全テストパス"
```

```bash
# ダッシュボード更新
./scripts/agent/update_dashboard.sh
./scripts/agent/update_dashboard.sh --log "Millerに指示送信"

# 仕事完了（レポート追記＋completedへ移動）
./scripts/agent/complete_task.sh task_20260130_auth "認証機能を実装" "passed"
./scripts/agent/complete_task.sh task_20260130_auth "バグ修正" "passed" "追加の最適化推奨"
```

各スクリプトの詳細は `-h` または `--help` オプションで確認できます。

## 使い方

### 初期セットアップ
```bash
./scripts/setup.sh
```

### 起動（Foremanが自動起動）
```bash
./scripts/start.sh
tmux attach -t windmill
```

start.shを実行すると:
1. tmuxセッションが作成される（6ペイン構成）
2. Foreman（親方）が自動起動し、ヒアリングを開始する
3. 他の職人は必要に応じて手動で起動

**レイアウト:**
```
┌─────────────────┬──────────────┬──────────────┐
│                 │   Foreman    │   Miller     │
│   Status        │   (ペイン1)  │   (ペイン2)  │
│   (ペイン0)     ├──────────────┼──────────────┤
│                 │   Sifter     │   Gleaner    │
│                 │   (ペイン4)  │   (ペイン3)  │
└─────────────────┴──────────────┴──────────────┘
```

### 職人起動（必要時）

#### Claude Code の場合
```bash
# Miller（挽き手）
tmux send-keys -t windmill:windmill.2 'claude --dangerously-skip-permissions' Enter

# Gleaner（聞き役）または ./scripts/start_gleaner.sh
tmux send-keys -t windmill:windmill.3 'claude --dangerously-skip-permissions' Enter

# Sifter（目利き）または ./scripts/start_sifter.sh
tmux send-keys -t windmill:windmill.4 'claude --dangerously-skip-permissions' Enter
```

#### OpenAI Codex CLI の場合
```bash
# Miller（挽き手）
tmux send-keys -t windmill:windmill.2 'codex --full-auto' Enter

# Gleaner（聞き役）
tmux send-keys -t windmill:windmill.3 'codex --full-auto' Enter

# Sifter（目利き）
tmux send-keys -t windmill:windmill.4 'codex --full-auto' Enter
```

#### GitHub Copilot CLI の場合
```bash
# Miller（挽き手）
tmux send-keys -t windmill:windmill.2 'copilot --allow-all' Enter

# Gleaner（聞き役）
tmux send-keys -t windmill:windmill.3 'copilot --allow-all' Enter

# Sifter（目利き）
tmux send-keys -t windmill:windmill.4 'copilot --allow-all' Enter
```

各職人は専用ディレクトリのAGENTS.mdを自動で読み込みます。

### 状況確認
```bash
./scripts/status.sh
```

### 停止
```bash
./scripts/stop.sh
```

## 通信方式

### tmux send-keys（重要）

職人間の通信は `tmux send-keys` を使用。**必ず2分割で送る**：

```bash
# OK: 動く
tmux send-keys -t windmill:windmill.1 "メッセージ"
tmux send-keys -t windmill:windmill.1 Enter

# NG: 動かない
tmux send-keys -t windmill:windmill.1 "メッセージ" Enter
```

### ペイン番号

- `windmill:windmill.0` - Status (監視パネル)
- `windmill:windmill.1` - Foreman (親方)
- `windmill:windmill.2` - Miller (挽き手)
- `windmill:windmill.3` - Gleaner (聞き役)
- `windmill:windmill.4` - Sifter (目利き)

## 仕事YAMLフォーマット

```yaml
# ファイル名: task_YYYYMMDD_summary.yaml
# 例: task_20260130_auth_feature.yaml
id: task_YYYYMMDD_summary
title: "仕事の説明"
status: pending  # pending, in_progress, review, completed, failed
assigned_to: null  # miller, sifter, gleaner
patron_input_required: false
breakdown:
  - "ステップ1"
  - "ステップ2"
work_log:
  - timestamp: "2025-01-29 10:00:00"
    action: "作業内容"
created_at: "2025-01-29 09:00:00"

# --- 以下は完了時にレポートとして追加 ---
completed_at: "2025-01-29 12:00:00"
completed_by: miller
result:
  summary: |
    作業の概要を簡潔に記載。
    何を実装/修正したか。
  changes:
    - file: path/to/file1
      description: "変更内容の説明"
    - file: path/to/file2
      description: "変更内容の説明"
  tests:
    status: passed  # passed, failed, skipped
    details: "テスト結果の詳細（件数等）"
  notes: |
    補足事項、注意点、今後の課題など。
```

## 仕事移動権限（重要）

**仕事ファイルの移動は Foremanのみが行う。他の職人は移動しない。**

### 仕事の状態遷移フロー

```
1. 旦那 → Foreman: 仕事の持ち込み
   ↓
2. Foreman: tasks/pending/ に仕事作成
   ↓
3. Foreman: pending/ → in_progress/ に移動（Millerに割り当て時）
   ↓
4. Miller: 作業実行、挽き上がり報告
   ↓
5. Foreman: 旦那に確認を求める
   ↓
6. 旦那: 受け取り or やり直し or 継続 を判断
   ↓
7. Foreman: 旦那の判断に従って移動
   - 受け取り → in_progress/ → completed/
   - 中断 → in_progress/ → failed/
   - 継続 → in_progress/ のまま（追加指示）
```

### 競合を避けるための原則

- **Miller**: 仕事ファイルは移動しない、work_log 更新と報告のみ
- **Foreman**: 仕事ファイルの移動、旦那への確認、最終判断を行う

## 旦那の介入

- **通常**: Foremanペイン（ペイン1）で対話
- **急ぎの時**: 各職人のペインで直接介入可能

## オンデマンド職人

### Gleaner（聞き役・調査専門）

**いつ使うか:**
- Millerに実装を頼む前に技術調査が必要な時
- ライブラリ/フレームワークの選定が必要な時
- 既存コードの構造理解が必要な時
- エラー原因の調査が必要な時

**起動方法:**
```bash
./scripts/start_gleaner.sh  # ペイン3でClaude自動起動
# 数秒待ってから指示を送る
```

**持ち込み形式:**
```
【調査持ち込み】task_20260130_state_mgmt: Reactの状態管理方法について調べてください。
調査ポイント: Redux vs Context API の比較、推奨される使い分け
```

### Sifter（目利き・レビュー専門）

**いつ使うか:**
- Millerから挽き上がり報告があり、コードレビューが必要な時
- 旦那が品質確認を求めた時
- 複雑な変更や重要な機能の実装後

**起動方法:**
```bash
./scripts/start_sifter.sh  # ペイン4でClaude自動起動
# 数秒待ってから指示を送る
```

**持ち込み形式:**
```
【レビュー持ち込み】task_20260130_auth: 以下のファイルを見てください。
対象: src/auth.js, src/middleware.js
```

### 使用フロー例

**事前調査パターン:**
```
旦那 → Foreman → Gleaner → Foreman → Miller → Foreman → 旦那
         (調査)    (結果)    (実装指示)  (挽き上がり) (受け取り)
```

**事後レビューパターン:**
```
旦那 → Foreman → Miller → Foreman → Sifter → Foreman → 旦那
         (実装指示) (挽き上がり) (レビュー) (結果)   (受け取り)
```

## ステータスマーカー

職人間の報告に含めるマーカー：

| 職人 | マーカー | 意味 |
|-------------|---------|------|
| Miller | `[MILLER:DONE]` | 挽き上がり |
| Miller | `[MILLER:BLOCKED]` | 手詰まり（旦那の判断必要） |
| Foreman | `[FOREMAN:APPROVE]` | 受け取り |
| Sifter | `[SIFTER:APPROVE]` | レビュー良し |
| Sifter | `[SIFTER:REQUEST_CHANGES]` | 直しあり |
| Sifter | `[SIFTER:COMMENT]` | 一言 |
| Gleaner | `[GLEANER:DONE]` | 調査完了 |
| Gleaner | `[GLEANER:NEED_MORE_INFO]` | もう少し情報が必要 |

## 自動実行モード

職人は自動実行モードで起動し、毎回の承認を不要にします。

### Claude Code
```bash
# 通常（毎回承認が必要）
claude

# 自動実行モード（承認なしで実行）
claude --dangerously-skip-permissions
```

### OpenAI Codex CLI
```bash
# 通常（提案モード）
codex

# 自動実行モード（承認なしで実行）
codex --full-auto
```

### GitHub Copilot CLI
```bash
# 通常（毎回承認が必要）
copilot

# 自動実行モード（承認なしで実行）
copilot --allow-all
```

緊急停止: `Ctrl+C` または `./scripts/stop.sh`
