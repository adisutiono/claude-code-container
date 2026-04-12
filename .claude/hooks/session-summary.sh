#!/usr/bin/env bash
# SessionEnd hook: append an LLM-generated summary to .claude/session-log.md
# Receives JSON on stdin with session_id, transcript_path, cwd.
set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

LOG_FILE="${CWD}/.claude/session-log.md"
mkdir -p "$(dirname "$LOG_FILE")"

[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

# Session metadata
SLUG=$(jq -r 'select(.slug != null) | .slug' "$TRANSCRIPT" 2>/dev/null | head -1)
[[ -z "$SLUG" || "$SLUG" == "null" ]] && SLUG=""
BRANCH=$(jq -r 'select(.gitBranch != null) | .gitBranch' "$TRANSCRIPT" 2>/dev/null | head -1)
[[ -z "$BRANCH" || "$BRANCH" == "null" ]] && BRANCH=""

# ── Build condensed transcript for LLM summary ─────────────────────────────
# Extract user requests and assistant text replies (skip tool calls, meta, XML tags)
CONDENSED=$(jq -r '
  select((.type == "user" and .isMeta != true) or .type == "assistant") |
  if .type == "user" then
    .message.content |
    if type == "string" then "USER: " + .
    elif type == "array" then
      [.[] | select(.type == "text") | .text | select(startswith("<") | not)] |
      if length > 0 then "USER: " + join(" ") else empty end
    else empty end
  elif .type == "assistant" then
    [.message.content[]? | select(.type == "text") | .text] |
    if length > 0 then "CLAUDE: " + (join(" ") | split("\n") | map(select(length > 0)) | first // "") else empty end
  else empty end
' "$TRANSCRIPT" 2>/dev/null | head -80)

[[ -z "$CONDENSED" ]] && exit 0

# ── Generate LLM summary ───────────────────────────────────────────────────
SUMMARY=""
if command -v claude &>/dev/null; then
  SUMMARY=$(echo "$CONDENSED" | claude -p \
    --model haiku \
    --no-session-persistence \
    "You are summarizing a Claude Code session for a developer's personal log. Write 2-4 sentences covering: (1) what the user requested, (2) what was accomplished, decided, or planned. Be specific about technical details but skip tool/process mechanics. No markdown formatting. Conversation:" \
    2>/dev/null) || SUMMARY=""
fi

# Fallback: use first user message as summary if LLM unavailable
if [[ -z "$SUMMARY" ]]; then
  SUMMARY=$(jq -r '
    select(.type == "user" and .isMeta != true) |
    .message.content |
    if type == "string" then .
    elif type == "array" then
      [.[] | select(.type == "text") | .text | select(startswith("<") | not)] | first // ""
    else "" end
  ' "$TRANSCRIPT" 2>/dev/null | head -1 | cut -c1-200)
  [[ -z "$SUMMARY" || "$SUMMARY" == "null" ]] && SUMMARY="(empty session)"
fi

# ── Append to log ───────────────────────────────────────────────────────────
if [[ ! -f "$LOG_FILE" ]]; then
  {
    echo "# Session Log"
    echo ""
    echo "Auto-generated summaries of Claude Code conversations."
    echo "This file is gitignored and local to this workspace."
    echo ""
    echo "---"
  } > "$LOG_FILE"
fi

{
  echo ""
  HEADER="### $(date '+%Y-%m-%d %H:%M')"
  [[ -n "$SLUG" ]] && HEADER="${HEADER} — ${SLUG}"
  echo "$HEADER"
  [[ -n "$BRANCH" ]] && echo "**Branch:** \`${BRANCH}\`"
  echo ""
  echo "$SUMMARY"
  echo ""
  echo "---"
} >> "$LOG_FILE"

exit 0
