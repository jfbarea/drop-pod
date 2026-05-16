#!/usr/bin/env bash
# Sends an ntfy.sh notification when Claude Code needs user attention
# (permission requests, confirmations, idle pauses, questions).
# Logs every invocation to ~/.claude/hooks/notify-attention.log for visibility.
# Requires NTFY_TOPIC to be set in the env.

LOG="$HOME/.claude/hooks/notify-attention.log"
mkdir -p "$(dirname "$LOG")"

{
  echo "--- $(date -Iseconds) ---"
  echo "PWD: $PWD"
  echo "NTFY_TOPIC: ${NTFY_TOPIC:-<unset>}"
} >> "$LOG"

TOPIC="${NTFY_TOPIC:-}"
if [[ -z "$TOPIC" ]]; then
  echo "exit: NTFY_TOPIC not set" >> "$LOG"
  echo "" >> "$LOG"
  exit 0
fi

INPUT=$(cat)
echo "stdin: $INPUT" >> "$LOG"

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"
PROJECT=$(basename "$CWD")
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // "Claude necesita tu atención"' 2>/dev/null)
[[ -z "$MESSAGE" || "$MESSAGE" == "null" ]] && MESSAGE="Claude necesita tu atención"

echo "publish: topic=$TOPIC project=$PROJECT" >> "$LOG"

RESPONSE=$(curl -sS \
  -w "\nHTTP_CODE=%{http_code}\n" \
  -H "Title: Claude Code · ${PROJECT} · atención" \
  -H "Priority: high" \
  -H "Tags: bell,question" \
  -d "$MESSAGE" \
  "https://ntfy.sh/${TOPIC}" 2>&1)
EXIT=$?

echo "curl exit: $EXIT" >> "$LOG"
echo "curl response: $RESPONSE" >> "$LOG"
echo "" >> "$LOG"
