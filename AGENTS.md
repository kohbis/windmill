# Windmill - Multi-Agent Development Environment

## Overview

Windmill is a multi-agent development environment where multiple AI coding agents collaborate on tasks.

**Supported AI Agents:**
- Claude Code (Anthropic) - `CLAUDE.md` / `AGENTS.md`
- OpenAI Codex CLI - `AGENTS.md`
- GitHub Copilot CLI - `AGENTS.md` / `.github/copilot-instructions.md`

**Metaphor**:
- Input (grain): Tasks brought in by the patron
- Processing (milling): Development work by the craftsmen
- Output (flour): Completed code and deliverables

## Agent Structure

| Role | Name | Responsibility | Availability |
|------|------|----------------|--------------|
| Manager | Foreman | Task decomposition, progress monitoring, patron interaction<br>**Never performs implementation work** | Always |
| Implementer | Miller | Main coding and implementation work<br>**Only acts on Foreman's instructions** | Always |
| Reviewer | Sifter | Code review, quality check | On-demand |
| Researcher | Gleaner | **Implementation planning (with Foreman)**, research, information gathering | Always |

### Role Division Principles

| Agent | Can Do | Prohibited |
|-------|--------|------------|
| **Foreman (Manager)** | - Task management<br>- Progress monitoring<br>- Starting agents<br>- Patron interaction | - Implementation work<br>- Research work<br>- Review work |
| **Miller (Implementer)** | - Coding<br>- Test execution<br>- Implementation work | - Task management<br>- Research work<br>- Review work<br>- Starting Gleaner/Sifter |
| **Sifter (Reviewer)** | - Code review<br>- Quality check | - Implementation work<br>- Research work<br>- Task management |
| **Gleaner (Researcher)** | - **Implementation planning**<br>- Technical research<br>- Information gathering | - Implementation work<br>- Review work<br>- Task management |

### Key Constraints

1. **Always plan with Gleaner before implementation** (Foreman ⇔ Gleaner)
2. **Only instruct Miller after patron approval of the plan**
3. **Only Foreman can start Gleaner/Sifter**
4. **Each agent handles only their specialty, no intervention in other areas**
5. **If Miller determines research/review is needed, report to Foreman for decision**
6. **All reports go through Foreman** (no direct communication between agents)

## Directory Structure

```
grist/
├── tasks/                     # Task management
│   ├── pending/               # Pending tasks
│   ├── in_progress/           # Tasks in progress
│   ├── completed/             # Completed tasks (with completion reports)
│   └── failed/                # Suspended/On hold
├── state/                     # Agent state management
│   ├── foreman.yaml
│   ├── miller.yaml
│   ├── sifter.yaml
│   └── gleaner.yaml
├── agents/                    # Agent-specific directories
│   ├── foreman/CLAUDE.md      # Foreman's prompt
│   ├── miller/CLAUDE.md       # Miller's prompt
│   ├── sifter/CLAUDE.md       # Sifter's prompt
│   └── gleaner/CLAUDE.md      # Gleaner's prompt
├── scripts/                   # Operation scripts
├── dashboard.md               # Progress management (updated by Foreman)

└── feedback/                  # Feedback from patron
    ├── inbox.md               # Unprocessed feedback
    └── archive.md             # Processed feedback
```

## Agent Scripts

Scripts for agents are placed in `scripts/agent/`.
These were created for token efficiency and reproducibility.

| Script | User | Purpose |
|--------|------|---------|
| `create_task.sh` | Foreman | Create task YAML (status: planning) |
| `update_plan.sh` | Foreman | Add implementation plan, record patron approval |
| `move_task.sh` | Foreman | Task status transition (pending→in_progress→completed/failed) |
| `send_to.sh` | All agents | Send instructions to agents (tmux send-keys wrapper) |
| `update_state.sh` | All agents | Update agent state files (state/*.yaml) |
| `log_work.sh` | Foreman, Miller | Append to task YAML work_log |
| `update_dashboard.sh` | Foreman | Auto-update dashboard, append work log |
| `complete_task.sh` | Foreman | Append completion report + move to completed |

### Usage Examples

```bash
# Create task YAML (created with status: planning)
./scripts/agent/create_task.sh "Implement authentication" "Step 1" "Step 2"

# After planning with Gleaner, add the plan
./scripts/agent/update_plan.sh task_20260130_auth "React" "Standard and proven" "medium" "Create components" "Add tests"

# When patron approves (change status to pending)
./scripts/agent/update_plan.sh --approve task_20260130_auth

# Assign task to Miller
./scripts/agent/move_task.sh task_20260130_auth in_progress miller

# Send instructions to Miller
./scripts/agent/send_to.sh miller "Process tasks/in_progress/task_20260130_auth.yaml"

# Complete task
./scripts/agent/move_task.sh task_20260130_auth completed
```

```bash
# Update agent state (4th argument for progress)
./scripts/agent/update_state.sh miller working task_20260130_auth "Started implementation"
./scripts/agent/update_state.sh miller blocked task_20260130_auth "External API connection error"
./scripts/agent/update_state.sh miller idle  # current_task and progress auto-cleared when idle

# Append to work_log
./scripts/agent/log_work.sh task_20260130_auth "Started implementation"
./scripts/agent/log_work.sh task_20260130_auth "Completed" "All tests passed"
```

```bash
# Update dashboard
./scripts/agent/update_dashboard.sh
./scripts/agent/update_dashboard.sh --log "Sent instructions to Miller"

# Complete task (append report + move to completed)
./scripts/agent/complete_task.sh task_20260130_auth "Implemented authentication" "passed"
./scripts/agent/complete_task.sh task_20260130_auth "Fixed bug" "passed" "Additional optimization recommended"
```

See each script's `-h` or `--help` option for details.

## Usage

### Initial Setup
```bash
./scripts/setup.sh
```

### Start (Foreman auto-starts)
```bash
./scripts/start.sh
tmux attach -t windmill
```

When you run start.sh:
1. A tmux session is created (6-pane layout)
2. Foreman auto-starts and begins hearing
3. Other agents are started manually as needed

**Layout:**
```
┌─────────────────┬──────────────┬──────────────┐
│                 │   Foreman    │   Miller     │
│   Status        │   (Pane 1)   │   (Pane 2)   │
│   (Pane 0)      ├──────────────┼──────────────┤
│                 │   Sifter     │   Gleaner    │
│                 │   (Pane 4)   │   (Pane 3)   │
└─────────────────┴──────────────┴──────────────┘
```

### Starting Agents (When Needed)

#### For Claude Code
```bash
# Miller (Implementer)
tmux send-keys -t windmill:windmill.2 'claude --dangerously-skip-permissions' Enter

# Gleaner (Researcher)
tmux send-keys -t windmill:windmill.3 'claude --dangerously-skip-permissions' Enter

# Sifter (Reviewer)
tmux send-keys -t windmill:windmill.4 'claude --dangerously-skip-permissions' Enter
```

#### For OpenAI Codex CLI
```bash
# Miller (Implementer)
tmux send-keys -t windmill:windmill.2 'codex --sandbox workspace-write --ask-for-approval never' Enter

# Gleaner (Researcher)
tmux send-keys -t windmill:windmill.3 'codex --sandbox workspace-write --ask-for-approval never' Enter

# Sifter (Reviewer)
tmux send-keys -t windmill:windmill.4 'codex --sandbox workspace-write --ask-for-approval never' Enter
```

#### For GitHub Copilot CLI
```bash
# Miller (Implementer)
tmux send-keys -t windmill:windmill.2 'copilot --allow-all' Enter

# Gleaner (Researcher)
tmux send-keys -t windmill:windmill.3 'copilot --allow-all' Enter

# Sifter (Reviewer)
tmux send-keys -t windmill:windmill.4 'copilot --allow-all' Enter
```

Each agent automatically reads the AGENTS.md from their dedicated directory.

### Status Check
```bash
./scripts/status.sh
```

### Stop
```bash
./scripts/stop.sh
```

## Communication Method

### tmux send-keys (Important)

Inter-agent communication uses `tmux send-keys`. **Always split into 2 parts with 0.2 second sleep**:

```bash
# OK: Works
tmux send-keys -t windmill:windmill.1 "Message"
sleep 0.2
tmux send-keys -t windmill:windmill.1 Enter

# NG: Does not work
tmux send-keys -t windmill:windmill.1 "Message" Enter

# NG: Does not work
tmux send-keys -t windmill:windmill.1 "Message"
# No sleep
tmux send-keys -t windmill:windmill.1 Enter
```

### Pane Numbers

- `windmill:windmill.0` - Status (monitoring panel)
- `windmill:windmill.1` - Foreman (Manager)
- `windmill:windmill.2` - Miller (Implementer)
- `windmill:windmill.3` - Gleaner (Researcher)
- `windmill:windmill.4` - Sifter (Reviewer)

## Task YAML Format

```yaml
# Filename: task_YYYYMMDD_summary.yaml
# Example: task_20260130_auth_feature.yaml
id: task_YYYYMMDD_summary
title: "Task description"
status: planning  # planning, pending, in_progress, review, completed, failed
assigned_to: null  # miller, sifter, gleaner
patron_input_required: false
breakdown:
  - "Step 1"
  - "Step 2"

# --- Implementation Plan (added after planning with Gleaner) ---
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
  patron_approved: false  # true after patron approval
  approved_at: null       # Approval timestamp

work_log:
  - timestamp: "2025-01-29 10:00:00"
    action: "Work content"
created_at: "2025-01-29 09:00:00"

# --- Added as report upon completion ---
completed_at: "2025-01-29 12:00:00"
completed_by: miller
result:
  summary: |
    Brief summary of the work.
    What was implemented/fixed.
  changes:
    - file: path/to/file1
      description: "Description of changes"
    - file: path/to/file2
      description: "Description of changes"
  tests:
    status: passed  # passed, failed, skipped
    details: "Test result details (count, etc.)"
  notes: |
    Supplementary notes, caveats, future tasks, etc.
```

### Status Meanings

| status | Meaning | Next Action |
|--------|---------|-------------|
| `planning` | Planning in progress | Develop plan with Gleaner |
| `pending` | Plan confirmed, patron approved | Can assign to Miller |
| `in_progress` | Implementation in progress | Miller is working |
| `review` | Under review | Sifter is reviewing |
| `completed` | Completed | Finished |
| `failed` | Suspended/On hold | Problem exists |

## Task Movement Permissions (Important)

**Only Foreman moves task files. Other agents do not move them.**

### Task State Transition Flow

```
1. Patron → Foreman: Task brought in
   ↓
2. Foreman: Create task in tasks/pending/ (status: planning)
   ↓
3. Foreman ⇔ Gleaner: Develop implementation plan [Required]
   ↓
4. Foreman → Patron: Report plan and request approval [Required]
   ↓
5. Patron: Approve or reject or adjust
   ↓
6. Foreman: If approved, move pending/ → in_progress/ (assign to Miller)
   ↓
7. Miller: Execute work, report completion
   ↓
8. Foreman: Request confirmation from patron
   ↓
9. Patron: Decide to accept or redo or continue
   ↓
10. Foreman: Move according to patron's decision
   - Accept → in_progress/ → completed/
   - Suspend → in_progress/ → failed/
   - Continue → stay in in_progress/ (additional instructions)
```

### Principles to Avoid Conflicts

- **Miller**: Does not move task files, only updates work_log and reports
- **Foreman**: Moves task files, confirms with patron, makes final decisions

## Patron Intervention

- **Normal**: Interact in Foreman pane (Pane 1)
- **Urgent**: Can intervene directly in each agent's pane

## On-Demand Agents

### Gleaner (Researcher)

**When to use:**
- When technical research is needed before asking Miller to implement
- When library/framework selection is needed
- When understanding existing code structure is needed
- When investigating error causes

**Request format:**
```
[Research Request] task_20260130_state_mgmt: Please research React state management methods.
Research points: Redux vs Context API comparison, recommended use cases
```

### Sifter (Reviewer)

**When to use:**
- When Miller reports completion and code review is needed
- When patron requests quality confirmation
- After complex changes or important feature implementation

**Request format:**
```
[Review Request] task_20260130_auth: Please review the following files.
Target: src/auth.js, src/middleware.js
```

### Usage Flow Examples

**Standard Pattern (Plan → Patron Approval → Implementation):**
```
Patron → Foreman → Gleaner → Foreman → Patron → Foreman → Miller → Foreman → Patron
         (Plan Request) (Plan Draft) (Report Plan) (Approve) (Implement) (Completion) (Accept)
```

**Post-Implementation Review Pattern:**
```
Patron → Foreman → Gleaner → Foreman → Patron → Foreman → Miller → Foreman → Sifter → Foreman → Patron
         (Plan Request) (Plan Draft) (Report Plan) (Approve) (Implement) (Completion) (Review) (Result) (Accept)
```

## Status Markers

Markers included in inter-agent reports:

| Agent | Marker | Meaning |
|-------|--------|---------|
| Miller | `[MILLER:DONE]` | Work completed |
| Miller | `[MILLER:BLOCKED]` | Blocked (patron decision needed) |
| Foreman | `[FOREMAN:APPROVE]` | Accepted |
| Sifter | `[SIFTER:APPROVE]` | Review passed |
| Sifter | `[SIFTER:REQUEST_CHANGES]` | Changes requested |
| Sifter | `[SIFTER:COMMENT]` | Comment |
| Gleaner | `[GLEANER:PLAN_READY]` | Implementation plan complete |
| Gleaner | `[GLEANER:DONE]` | Research complete |
| Gleaner | `[GLEANER:NEED_MORE_INFO]` | More information needed |

## Automatic Execution Mode

Agents are started in automatic execution mode, eliminating the need for approval each time.

### Claude Code
```bash
# Normal (approval required each time)
claude

# Automatic execution mode (execute without approval)
claude --dangerously-skip-permissions
```

### OpenAI Codex CLI
```bash
# Normal (suggestion mode)
codex

# Automatic execution mode (sandbox enabled, no approval prompts)
codex --sandbox workspace-write --ask-for-approval never
```

### GitHub Copilot CLI
```bash
# Normal (approval required each time)
copilot

# Automatic execution mode (execute without approval)
copilot --allow-all
```

Emergency stop: `Ctrl+C` or `./scripts/stop.sh`
