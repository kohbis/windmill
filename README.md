# Windmill

Multi-AI Agent Collaborative Development Framework

A tmux-based multi-agent environment where multiple AI coding agents work together with role-based division of labor to execute development tasks.

## Features

- **Role Division**: 4-agent structure for management, implementation, review, and research
- **Automatic Coordination**: Automated task handoff between agents
- **Progress Visualization**: Real-time status monitoring via dashboard
- **Multi-Agent Support**: Claude Code / OpenAI Codex CLI / GitHub Copilot CLI

## Requirements

- macOS / Linux
- [tmux](https://github.com/tmux/tmux) 3.0+
- One of the following AI agents:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic)
  - [OpenAI Codex CLI](https://github.com/openai/codex) (OpenAI)
  - [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) (GitHub)

> [!WARNING]
> This framework launches agents in automatic execution mode.
> - Claude Code: `--dangerously-skip-permissions`
> - OpenAI Codex CLI: `--dangerously-bypass-approvals-and-sandbox`
> - GitHub Copilot CLI: `--allow-all`
>
> These options allow agents to perform file operations and command execution without confirmation.
> Use only in trusted environments.

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/kohbis/windmill.git
cd windmill

# 2. Setup
./scripts/setup.sh

# 3. Start
./scripts/start.sh ${AGENT_TYPE} # AGENT_TYPE: claude (default) | codex | copilot
# e.g, ./scripts/start.sh codex

# 4. Attach to tmux session
tmux attach -t windmill
```

After startup, Foreman automatically starts and begins task hearing.

## Agent Structure

| Role | Name | Responsibility |
|------|------|----------------|
| Management | Foreman | Task decomposition, progress monitoring, user interaction |
| Implementation | Miller | Coding and implementation work |
| Review | Sifter | Code review, quality check |
| Research | Gleaner | Technical research, information gathering |

## tmux Layout

```
┌─────────────────┬──────────────┬──────────────┐
│                 │   Foreman    │   Miller     │
│   Status        │   (Pane 1)   │   (Pane 2)   │
│   (Pane 0)      ├──────────────┼──────────────┤
│                 │   Sifter     │   Gleaner    │
│                 │   (Pane 4)   │   (Pane 3)   │
└─────────────────┴──────────────┴──────────────┘
```

## Basic Usage

### Requesting Tasks

Communicate tasks in the Foreman pane (Pane 1):

```
Please implement authentication feature. Use JWT tokens and
need endpoints for login, logout, and token refresh.
```

Foreman decomposes the task and issues instructions to Miller.

### Status Check / Stop

```bash
# Check status
./scripts/status.sh

# Stop
./scripts/stop.sh
```

## Workflow Examples

### Basic Flow
```
User → Foreman → Miller → Foreman → User
       (Decompose) (Implement) (Report) (Confirm)
```

### Flow with Research
```
User → Foreman → Gleaner → Foreman → Miller → Foreman → User
       (Research Request) (Research) (Share Results) (Implement) (Report)
```

### Flow with Review
```
User → Foreman → Miller → Foreman → Sifter → Foreman → User
       (Implementation Request) (Implement) (Review Request) (Review) (Report)
```

## Directory Structure

```
windmill/
├── agents/           # Agent prompts
│   ├── foreman/
│   ├── miller/
│   ├── sifter/
│   └── gleaner/
├── tasks/            # Task management
│   ├── pending/      # Pending
│   ├── in_progress/  # In progress
│   ├── completed/    # Completed
│   └── failed/       # Failed/Suspended
├── state/            # Agent state (YAML)
├── feedback/         # Feedback
├── scripts/          # Operation scripts
│   └── agent/        # Agent scripts
└── dashboard.md      # Progress dashboard
```

## Detailed Documentation

For detailed specifications and settings, see [AGENTS.md](AGENTS.md).

## License

MIT License, see [LICENSE](LICENSE) for details.
