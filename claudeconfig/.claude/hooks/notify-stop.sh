#!/usr/bin/env bash
# Notifica cuando termina una sesión de Claude Code.
#   - Banner nativo local (macOS alerter / Linux notify-send), siempre.
#   - Push a ntfy.sh si NTFY_TOPIC está definido.
# Registra cada invocación en ~/.claude/hooks/notify-stop.log para depurar.

LOG="$HOME/.claude/hooks/notify-stop.log"
mkdir -p "$(dirname "$LOG")"

# Banner nativo local. Pasa título/cuerpo por argv para evitar escapado/inyección.
# En macOS usa alerter (terminal-notifier 2.0.0 ya no registra su bundle en macOS
# reciente y descarta los banners en silencio). alerter es bloqueante y reporta la
# activación por stdout en JSON, así que se lanza desacoplado (nohup … &) para no
# bloquear el hook; si el usuario pincha el banner (contentsClicked) se eleva la
# ventana de Ghostty cuyo título contiene "$needle" (el proyecto).
notify_local() {
  local title="$1" body="$2" needle="${3:-}"
  case "$(uname -s)" in
    Darwin)
      if command -v alerter >/dev/null 2>&1; then
        nohup bash -c '
          r=$("$1" --title "$2" --message "$3" --sound Glass --timeout 60 --json 2>/dev/null)
          printf "%s" "$r" | grep -q "\"activationType\" : \"contentsClicked\"" \
            && "$4" "$5"
        ' _ "$(command -v alerter)" "$title" "$body" \
          "$HOME/.claude/hooks/ghostty-focus.sh" "$needle" >/dev/null 2>&1 &
        disown 2>/dev/null || true
      else
        osascript - "$title" "$body" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"
end run
APPLESCRIPT
      fi
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
printf '%s' "$PROJECT" > "$HOME/.claude/hooks/last-notify"

# 1) Banner local — siempre, independientemente de NTFY_TOPIC.
notify_local "Claude Code · ${PROJECT}" "Sesión terminada en ${CWD}" "${PROJECT}"

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
  -H "Title: Claude Code · ${PROJECT}" \
  -H "Priority: default" \
  -H "Tags: robot" \
  -d "Sesión terminada en ${CWD}" \
  "https://ntfy.sh/${TOPIC}" 2>&1)
EXIT=$?

echo "curl exit: $EXIT" >> "$LOG"
echo "curl response: $RESPONSE" >> "$LOG"
echo "" >> "$LOG"
