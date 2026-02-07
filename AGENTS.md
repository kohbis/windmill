# Windmill - Multi-Agent Development Environment

## Overview
Windmill is a multi-agent development environment where AI agents collaborate on tasks.

Supported agents:
- Claude Code (Anthropic) - `CLAUDE.md` / `AGENTS.md`
- OpenAI Codex CLI - `AGENTS.md`
- GitHub Copilot CLI - `AGENTS.md` / `.github/copilot-instructions.md`

Metaphor:
- Input (grain): tasks brought in by the patron
- Processing (milling): development work by the craftsmen
- Output (flour): completed code and deliverables

## Agent Structure

| Role | Name | Responsibility | Availability |
|------|------|----------------|--------------|
| Manager | Foreman | Task decomposition, progress monitoring, patron interaction (never implements) | Always |
| Implementer | Miller | Coding and implementation (only acts on Foreman instructions) | Always |
| Reviewer | Sifter | Code review, quality checks | On-demand |
| Researcher | Gleaner | Planning, research, info gathering | Always |

### Role Division (What each can do)

| Agent | Can Do | Prohibited |
|-------|--------|------------|
| Foreman | Task management, progress monitoring, start agents, patron interaction | Implementation, research, review |
| Miller | Coding, tests, implementation | Task management, research, review, start agents |
| Sifter | Review, quality check | Implementation, research, task management |
| Gleaner | Planning, research, information gathering | Implementation, review, task management |

### Key Constraints
1. Always plan with Gleaner before implementation (Foreman ⇔ Gleaner).
2. Foreman instructs Miller only after patron approval.
3. Only Foreman can start Gleaner/Sifter.
4. Each agent stays within role boundaries.
5. If Miller needs research/review, report to Foreman.
6. All reports go through Foreman (no cross-agent chatter).

## Directory Structure

```
grist/
├── tasks/       # pending, in_progress, completed, failed
├── state/       # foreman.yaml, miller.yaml, sifter.yaml, gleaner.yaml
├── agents/      # role prompts
├── scripts/     # operations
├── dashboard.md # updated by Foreman
└── feedback/    # patron feedback
```

## Agent Scripts (scripts/agent/)

| Script | User | Purpose |
|--------|------|---------|
| `create_task.sh` | Foreman | Create task YAML (status: planning) |
| `update_plan.sh` | Foreman | Add plan + record approval |
| `move_task.sh` | Foreman | Move tasks between states |
| `send_to.sh` | All | Send message to agent (tmux wrapper) |
| `update_state.sh` | All | Update agent state files |
| `log_work.sh` | Foreman, Miller | Append task work_log |
| `update_dashboard.sh` | Foreman | Refresh dashboard |
| `complete_task.sh` | Foreman | Append completion report + move to completed |

Quick usage:
```bash
./scripts/agent/create_task.sh "Implement auth" "Step 1" "Step 2"
./scripts/agent/update_plan.sh task_20260130_auth "React" "Reason" "medium" "Step A" "Step B"
./scripts/agent/update_plan.sh --approve task_20260130_auth
./scripts/agent/move_task.sh task_20260130_auth in_progress miller
./scripts/agent/send_to.sh miller "Process tasks/in_progress/task_20260130_auth.yaml"
./scripts/agent/log_work.sh task_20260130_auth "Started implementation"
./scripts/agent/update_state.sh miller working task_20260130_auth "Started"
./scripts/agent/complete_task.sh task_20260130_auth "Summary" "passed"
```

## Running the System

Initial setup:
```bash
./scripts/setup.sh
```

Start (Foreman auto-starts):
```bash
./scripts/start.sh
# attach
# tmux attach -t windmill
```

Status / Stop:
```bash
./scripts/status.sh
./scripts/stop.sh
```

### tmux Layout & Pane Numbers
```
┌─────────────────┬──────────────┬──────────────┐
│                 │   Foreman    │   Miller     │
│   Status        │   (Pane 1)   │   (Pane 2)   │
│   (Pane 0)      ├──────────────┼──────────────┤
│                 │   Sifter     │   Gleaner    │
│                 │   (Pane 4)   │   (Pane 3)   │
└─────────────────┴──────────────┴──────────────┘
```

Pane IDs:
- `windmill:windmill.0` Status
- `windmill:windmill.1` Foreman
- `windmill:windmill.2` Miller
- `windmill:windmill.3` Gleaner
- `windmill:windmill.4` Sifter

### tmux send-keys (Important)
Always split into two sends with a 0.2s delay:
```bash
tmux send-keys -t windmill:windmill.1 "Message"
sleep 0.2
tmux send-keys -t windmill:windmill.1 Enter
```
Do not send message + Enter in one call.

## Task YAML Format
```yaml
# Filename: task_YYYYMMDD_summary.yaml
id: task_YYYYMMDD_summary
title: "Task description"
status: planning  # planning, pending, in_progress, review, completed, failed
assigned_to: null  # miller, sifter, gleaner
patron_input_required: false
breakdown:
  - "Step 1"
  - "Step 2"

# --- Implementation Plan ---
plan:
  tech_selection: "Library/framework to use"
  tech_reason: |
    Reason for selection
  architecture: |
    File structure and module division explanation
  implementation_steps:
    - "Detailed step 1"
    - "Detailed step 2"
  risks:
    - "Concern 1"
    - "Concern 2"
  estimated_size: medium  # small, medium, large
  planned_by: gleaner
  planned_at: "YYYY-MM-DD HH:MM:SS"
  patron_approved: false
  approved_at: null

work_log:
  - timestamp: "2025-01-29 10:00:00"
    action: "Work content"
created_at: "2025-01-29 09:00:00"

# --- Completion Report ---
completed_at: "2025-01-29 12:00:00"
completed_by: miller
result:
  summary: |
    Summary of work.
  changes:
    - file: path/to/file1
      description: "Change description"
  tests:
    status: passed  # passed, failed, skipped
    details: "Test result details"
  notes: |
    Notes and follow-ups.
```

### Status Meanings
| status | Meaning | Next Action |
|--------|---------|-------------|
| `planning` | Planning in progress | Foreman + Gleaner plan |
| `pending` | Plan approved | Can assign to Miller |
| `in_progress` | Implementation | Miller working |
| `review` | Under review | Sifter reviewing |
| `completed` | Finished | Done |
| `failed` | Suspended | Blocked/On hold |

### Task Movement Permissions
Only Foreman moves task files between `pending/`, `in_progress/`, `completed/`, `failed/`.

### Task Flow
1. Patron → Foreman (task)
2. Foreman → Gleaner (plan)
3. Foreman → Patron (plan approval)
4. Foreman → Miller (implement)
5. Miller → Foreman (completion)
6. Optional: Foreman → Sifter (review)
7. Foreman → Patron (accept / redo / suspend)
8. If redo: Foreman → Miller (iterate), repeat review/accept loop as needed

## On-Demand Agents

Gleaner (Researcher) request:
```
[Research Request] task_20260130_state_mgmt: Please research React state management methods.
Research points: Redux vs Context API comparison, recommended use cases
```

Sifter (Reviewer) request:
```
[Review Request] task_20260130_auth: Please review the following files.
Target: src/auth.js, src/middleware.js
```

## Status Markers
| Agent | Marker | Meaning |
|-------|--------|---------|
| Miller | `[MILLER:DONE]` | Work completed |
| Miller | `[MILLER:BLOCKED]` | Blocked |
| Foreman | `[FOREMAN:APPROVE]` | Accepted |
| Sifter | `[SIFTER:APPROVE]` | Review passed |
| Sifter | `[SIFTER:REQUEST_CHANGES]` | Changes requested |
| Sifter | `[SIFTER:COMMENT]` | Comment |
| Gleaner | `[GLEANER:PLAN_READY]` | Plan ready |
| Gleaner | `[GLEANER:DONE]` | Research done |
| Gleaner | `[GLEANER:NEED_MORE_INFO]` | More info needed |

## Automatic Execution Mode

Claude Code:
```bash
claude --dangerously-skip-permissions
```

OpenAI Codex CLI:
```bash
codex --dangerously-bypass-approvals-and-sandbox
```

GitHub Copilot CLI:
```bash
copilot --allow-all
```

Emergency stop: `Ctrl+C` or `./scripts/stop.sh`
