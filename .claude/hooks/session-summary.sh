#!/usr/bin/env bash
# SessionEnd hook: append an LLM-generated summary to .claude/session-log.md
# Receives JSON on stdin with session_id, transcript_path, cwd.
set -euo pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

LOG_FILE="${CWD}/.claude/session-log.md"
mkdir -p "$(dirname "$LOG_FILE")"

[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

# Session metadata
SLUG=$(jq -s -r '[.[] | select(.slug != null) | .slug] | first // ""' "$TRANSCRIPT" 2>/dev/null || true)
[[ -z "$SLUG" || "$SLUG" == "null" ]] && SLUG=""
BRANCH=$(jq -s -r '[.[] | select(.gitBranch != null) | .gitBranch] | first // ""' "$TRANSCRIPT" 2>/dev/null || true)
[[ -z "$BRANCH" || "$BRANCH" == "null" ]] && BRANCH=""

# ── Build condensed transcript for LLM summary ─────────────────────────────
# Extract user requests and assistant text replies.
# Filter out: meta messages, XML-tagged system content (commands, IDE events,
# local stdout), tool calls, and empty lines.
CONDENSED=$(jq -s -r '[
  .[] |
  select((.type == "user" and .isMeta != true) or .type == "assistant") |
  if .type == "user" then
    .message.content |
    if type == "string" then
      if startswith("<") then empty else "USER: " + . end
    elif type == "array" then
      [.[] | select(.type == "text") | .text | select(startswith("<") | not)] |
      if length > 0 then "USER: " + join(" ") else empty end
    else empty end
  elif .type == "assistant" then
    [.message.content[]? | select(.type == "text") | .text] |
    if length > 0 then "CLAUDE: " + (join(" ") | split("\n") | map(select(length > 0)) | first // "") else empty end
  else empty end
] | .[:80] | .[]' "$TRANSCRIPT" 2>/dev/null || true)

[[ -z "$CONDENSED" ]] && exit 0

# ── Generate LLM summary ───────────────────────────────────────────────────
SUMMARY=""
if command -v claude &>/dev/null; then
  SUMMARY=$(echo "$CONDENSED" | claude -p \
    --model haiku \
    --no-session-persistence \
    "You are summarizing a Claude Code session for a developer's personal log. Write 2-4 sentences covering: (1) what the user requested, (2) what was accomplished, decided, or planned. Short user replies like 'yes' or 'no' are responses to the preceding Claude message — infer context from the conversation flow. Be specific about technical details but skip tool/process mechanics. No markdown formatting. Conversation:" \
    2>/dev/null) || SUMMARY=""
fi

# Fallback: use first user message as summary if LLM unavailable
if [[ -z "$SUMMARY" ]]; then
  SUMMARY=$(jq -s -r '[
    .[] |
    select(.type == "user" and .isMeta != true) |
    .message.content |
    if type == "string" then
      if startswith("<") then empty else . end
    elif type == "array" then
      [.[] | select(.type == "text") | .text | select(startswith("<") | not)] | first // empty
    else empty end
  ] | first // "(empty session)"' "$TRANSCRIPT" 2>/dev/null | cut -c1-200)
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
