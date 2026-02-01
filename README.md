# Windmill

マルチAIエージェント協調開発フレームワーク

複数のAIコーディングエージェントが役割分担して開発タスクを遂行する、tmuxベースのマルチエージェント環境です。

## 特徴

- **役割分担**: 管理・実装・レビュー・調査の4エージェント体制
- **自動協調**: エージェント間のタスク受け渡しを自動化
- **進捗可視化**: ダッシュボードでリアルタイムに状況把握
- **マルチエージェント対応**: Claude Code / OpenAI Codex CLI / GitHub Copilot CLI

## 必要条件

- macOS / Linux
- [tmux](https://github.com/tmux/tmux) 3.0+
- 以下のいずれかのAIエージェント:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic)
  - [OpenAI Codex CLI](https://github.com/openai/codex) (OpenAI)
  - [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) (GitHub)

## クイックスタート

```bash
# 1. リポジトリをクローン
git clone https://github.com/kohbis/windmill.git
cd windmill

# 2. セットアップ
./scripts/setup.sh

# 3. 起動
./scripts/start.sh ${AGENT_TYPE} # AGENT_TYPE: claude (default) | codex | copilot
# e.g, ./scripts/start.sh codex

# 4. tmuxセッションに接続
tmux attach -t windmill
```

起動後、Foremanが自動起動し、タスクのヒアリングを開始します。

## エージェント構成

| 役割 | 名前 | 責務 |
|------|------|------|
| 管理 | Foreman | タスク分解・進捗監視・ユーザー対話 |
| 実装 | Miller | コーディング・実装作業 |
| レビュー | Sifter | コードレビュー・品質チェック |
| 調査 | Gleaner | 技術調査・情報収集 |

## tmuxレイアウト

```
┌─────────────────┬──────────────┬──────────────┐
│                 │   Foreman    │   Miller     │
│   Status        │   (ペイン1)  │   (ペイン2)  │
│   (ペイン0)     ├──────────────┼──────────────┤
│                 │   Sifter     │   Gleaner    │
│                 │   (ペイン4)  │   (ペイン3)  │
└─────────────────┴──────────────┴──────────────┘
```

## 基本的な使い方

### タスクを依頼する

Foremanペイン（ペイン1）でタスクを伝えます：

```
認証機能を実装してください。JWTトークンを使用し、
ログイン・ログアウト・トークンリフレッシュのエンドポイントが必要です。
```

Foremanがタスクを分解し、Millerに指示を出します。

### 状況確認・停止

```bash
# 状況確認
./scripts/status.sh

# 停止
./scripts/stop.sh
```

## ワークフロー例

### 基本フロー
```
User → Foreman → Miller → Foreman → User
       (分解)    (実装)   (報告)   (確認)
```

### 調査付きフロー
```
User → Foreman → Gleaner → Foreman → Miller → Foreman → User
       (調査依頼)  (調査)   (結果共有)  (実装)   (報告)
```

### レビュー付きフロー
```
User → Foreman → Miller → Foreman → Sifter → Foreman → User
       (実装依頼) (実装)   (レビュー依頼) (レビュー) (報告)
```

## ディレクトリ構造

```
windmill/
├── agents/           # エージェントプロンプト
│   ├── foreman/
│   ├── miller/
│   ├── sifter/
│   └── gleaner/
├── tasks/            # タスク管理
│   ├── pending/      # 待機中
│   ├── in_progress/  # 進行中
│   ├── completed/    # 完了
│   └── failed/       # 失敗/中断
├── state/            # エージェント状態（YAML）
├── feedback/         # フィードバック
├── scripts/          # 操作スクリプト
│   └── agent/        # エージェント用スクリプト
└── dashboard.md      # 進捗ダッシュボード
```

## 詳細ドキュメント

詳しい仕様・設定については [AGENTS.md](AGENTS.md) を参照してください。

## ライセンス

MIT License
