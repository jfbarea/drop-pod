#!/usr/bin/env bash
# Sends an ntfy.sh notification when a Claude Code session ends.
# Requires NTFY_TOPIC to be set in the shell environment.

TOPIC="${NTFY_TOPIC:-}"
[[ -z "$TOPIC" ]] && exit 0

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"
PROJECT=$(basename "$CWD")

curl -sS \
  -H "Title: Claude Code · ${PROJECT}" \
  -H "Priority: default" \
  -H "Tags: robot" \
  -d "Sesión terminada en ${CWD}" \
  "https://ntfy.sh/${TOPIC}" \
  >/dev/null 2>&1 || true
