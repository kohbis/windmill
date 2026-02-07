#!/bin/bash
# add_feedback.sh - Append feedback to feedback/inbox.md
# Creates inbox.md from template if it does not exist.
#
# Examples:
#   ./scripts/agent/add_feedback.sh "20260130_impl_auth_feat" "Impl Auth" "Good test coverage" "Naming could be better"
#   ./scripts/agent/add_feedback.sh --general "Workflow" "Need faster review turnaround"

set -e

MILL_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INBOX="$MILL_ROOT/feedback/inbox.md"
TEMPLATE="$MILL_ROOT/feedback/inbox.md.template"

# Display help
show_help() {
    cat << 'EOF'
Usage:
  add_feedback.sh <task_id> "<task_title>" "<feedback>" ["<feedback2>" ...]
  add_feedback.sh --general "<category>" "<feedback>" ["<feedback2>" ...]

Appends feedback to feedback/inbox.md.
If inbox.md does not exist, it is created from the template.

Task feedback:
  add_feedback.sh 20260130_impl_auth_feat "Impl Auth" "Good coverage" "Naming needs work"

General feedback:
  add_feedback.sh --general "Workflow" "Review turnaround too slow"
  add_feedback.sh --general "Tools" "Need better linting"
EOF
    exit 0
}

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
fi

# Create inbox.md from template if missing
if [ ! -f "$INBOX" ]; then
    if [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$INBOX"
        echo "Created feedback/inbox.md from template."
    else
        cat > "$INBOX" << 'HEADER'
# Feedback Inbox

Accumulates unaddressed feedback.
After addressing, move to archive.md.

---

HEADER
        echo "Created feedback/inbox.md (template not found, generated default)."
    fi
fi

TODAY=$(date '+%Y-%m-%d')

# Check if today's date header already exists
has_today_header() {
    grep -q "^## $TODAY" "$INBOX"
}

# Append today's date header if not present
ensure_today_header() {
    if ! has_today_header; then
        printf '\n## %s\n' "$TODAY" >> "$INBOX"
    fi
}

if [ "$1" = "--general" ]; then
    # General feedback: --general "<category>" "<feedback>" ...
    shift
    CATEGORY="$1"
    shift

    if [ $# -lt 1 ]; then
        echo "Error: At least one feedback line is required."
        exit 1
    fi

    ensure_today_header

    {
        printf '\n### [General] %s\n' "$CATEGORY"
        for line in "$@"; do
            printf -- '- %s\n' "$line"
        done
    } >> "$INBOX"

    echo "Feedback appended (General/$CATEGORY)."
else
    # Task feedback: <task_id> "<task_title>" "<feedback>" ...
    TASK_ID="$1"
    TASK_TITLE="$2"
    shift 2

    if [ $# -lt 1 ]; then
        echo "Error: At least one feedback line is required."
        exit 1
    fi

    ensure_today_header

    {
        printf '\n### [%s] %s\n' "$TASK_ID" "$TASK_TITLE"
        for line in "$@"; do
            printf -- '- %s\n' "$line"
        done
    } >> "$INBOX"

    echo "Feedback appended ($TASK_ID)."
fi
