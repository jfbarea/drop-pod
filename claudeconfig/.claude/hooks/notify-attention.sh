#!/usr/bin/env bash
# Notifica cuando Claude Code necesita atención del usuario
# (permisos, confirmaciones, pausas, preguntas).
#   - Banner nativo local (macOS osascript / Linux notify-send), siempre.
#   - Push a ntfy.sh si NTFY_TOPIC está definido.
# Registra cada invocación en ~/.claude/hooks/notify-attention.log para depurar.

LOG="$HOME/.claude/hooks/notify-attention.log"
mkdir -p "$(dirname "$LOG")"

# Banner nativo local. Pasa título/cuerpo por argv para evitar escapado/inyección.
notify_local() {
  local title="$1" body="$2"
  case "$(uname -s)" in
    Darwin)
      osascript - "$title" "$body" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"
end run
APPLESCRIPT
      ;;
    Linux)
      command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$body" >/dev/null 2>&1 || true
      ;;
  esac
}

{
  echo "--- $(date -Iseconds) ---"
  echo "PWD: $PWD"
  echo "NTFY_TOPIC: ${NTFY_TOPIC:-<unset>}"
} >> "$LOG"

# stdin se lee una sola vez y se reutiliza para banner local y ntfy.
INPUT=$(cat)
echo "stdin: $INPUT" >> "$LOG"

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD="${CWD:-$PWD}"
PROJECT=$(basename "$CWD")
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // "Claude necesita tu atención"' 2>/dev/null)
[[ -z "$MESSAGE" || "$MESSAGE" == "null" ]] && MESSAGE="Claude necesita tu atención"

# 1) Banner local — siempre, independientemente de NTFY_TOPIC.
notify_local "Claude Code · ${PROJECT} · atención" "$MESSAGE"

# 2) Push a ntfy — solo si hay topic.
TOPIC="${NTFY_TOPIC:-}"
if [[ -z "$TOPIC" ]]; then
  echo "ntfy skip: NTFY_TOPIC not set" >> "$LOG"
  echo "" >> "$LOG"
  exit 0
fi

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
