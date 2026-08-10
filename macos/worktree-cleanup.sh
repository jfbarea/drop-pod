#!/usr/bin/env bash
set -uo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY_RUN=1

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

TODAY="$(date +%F)"
STATE_DIR="$HOME/.local/state/worktree-cleanup"
RUN_LOG="$STATE_DIR/run.log"
OUTPUT="$STATE_DIR/last-run-output.txt"
REPORT="$STATE_DIR/report-${TODAY}.md"
LOCK_DIR="$STATE_DIR/.lock"
RETENTION_DAYS=90
NETWORK_ATTEMPTS=10
NETWORK_WAIT=30
RUN_TIMEOUT=1800

mkdir -p "$STATE_DIR"

log() { echo "$(date -Iseconds) $*" >> "$RUN_LOG"; }

resolve_ntfy_topic() {
  if [[ -n "${NTFY_TOPIC:-}" ]]; then
    printf '%s' "$NTFY_TOPIC"
    return 0
  fi
  local f topic
  for f in "$HOME/.zshrc.local" "$HOME/.zshrc"; do
    [[ -r "$f" ]] || continue
    topic="$(sed -n 's/^[[:space:]]*export[[:space:]]\{1,\}NTFY_TOPIC=\([^[:space:]#]*\).*/\1/p' \
      "$f" | head -1)"
    if [[ -n "$topic" ]]; then
      printf '%s' "$topic"
      return 0
    fi
  done
}

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-broom}"

  if [[ "$(uname -s)" == "Darwin" ]] && command -v alerter >/dev/null 2>&1; then
    nohup "$(command -v alerter)" --title "$title" \
      --message "$(printf '%s' "$body" | head -3 | tr '\n' ' ')" \
      --sound Glass --timeout 60 >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi

  local topic
  topic="$(resolve_ntfy_topic)"
  if [[ -z "$topic" ]]; then
    log "ntfy skip: NTFY_TOPIC sin resolver"
    return 0
  fi

  curl -sS -o /dev/null \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Markdown: yes" \
    --data-binary @- \
    "https://ntfy.sh/${topic}" <<< "$body" 2>>"$RUN_LOG" \
    || log "ntfy falló (topic=$topic)"
}

find "$STATE_DIR" -maxdepth 1 -type f \( -name 'report-*.md' -o -name 'deleted-branches-*.txt' \) \
  -mtime +"$RETENTION_DAYS" -delete 2>/dev/null

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [[ -r "$LOCK_DIR/pid" ]] && kill -0 "$(<"$LOCK_DIR/pid")" 2>/dev/null; then
    log "otra ejecución en curso (pid $(<"$LOCK_DIR/pid")); saliendo"
    exit 0
  fi
  log "lock huérfano; reclamando"
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" 2>/dev/null || { log "no se pudo tomar el lock"; exit 0; }
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

command -v claude >/dev/null 2>&1 || { log "ERROR: claude no está en PATH"; exit 1; }
command -v gh    >/dev/null 2>&1 || { log "ERROR: gh no está en PATH"; exit 1; }

network_ready=0
for ((i = 1; i <= NETWORK_ATTEMPTS; i++)); do
  if curl -sfI --max-time 10 https://api.github.com >/dev/null 2>&1; then
    network_ready=1
    break
  fi
  [[ $i -lt $NETWORK_ATTEMPTS ]] && sleep "$NETWORK_WAIT"
done
if [[ $network_ready -eq 0 ]]; then
  log "sin red tras $NETWORK_ATTEMPTS intentos; saliendo en silencio"
  exit 0
fi

if [[ -r "$HOME/.claude/token" ]]; then
  export CLAUDE_CODE_OAUTH_TOKEN="$(<"$HOME/.claude/token")"
fi
export CLAUDE_NO_NOTIFY=1

PROMPT="/worktree-cleanup"
[[ $DRY_RUN -eq 1 ]] && PROMPT="/worktree-cleanup --dry-run"

runner=(env)
if command -v timeout >/dev/null 2>&1; then
  runner=(timeout "$RUN_TIMEOUT")
elif command -v gtimeout >/dev/null 2>&1; then
  runner=(gtimeout "$RUN_TIMEOUT")
fi

title="Worktree cleanup · $TODAY"
[[ $DRY_RUN -eq 1 ]] && title="$title · dry-run"

rm -f "$REPORT"
log "inicio (dry-run=$DRY_RUN)"

cd "$HOME" || exit 1
"${runner[@]}" claude -p "$PROMPT" --permission-mode acceptEdits >"$OUTPUT" 2>&1
status=$?

if [[ $status -ne 0 ]]; then
  log "FALLO: claude salió con $status"
  notify "$title · falló" \
    "La limpieza de worktrees falló (exit $status). Revisa $OUTPUT y $RUN_LOG." \
    high "warning"
  exit "$status"
fi

if [[ ! -s "$REPORT" ]]; then
  log "FALLO: la ejecución terminó sin escribir $REPORT"
  notify "$title · sin informe" \
    "La limpieza terminó sin escribir el informe en $REPORT, así que no hay rastro de lo que hizo. Revisa $OUTPUT." \
    high "warning"
  exit 1
fi

estado="$(head -1 "$REPORT")"

if [[ "$estado" == *silencioso* ]]; then
  log "nada que reportar"
  exit 0
fi

priority=default
tags=broom
if [[ "$estado" == *requiere-decision* ]]; then
  priority=high
  tags="broom,warning"
fi

body="$(cat "$REPORT")"
if [[ ${#body} -gt 3500 ]]; then
  body="${body:0:3500}"$'\n\n…informe truncado. Completo en '"$REPORT"
fi

notify "$title" "$body" "$priority" "$tags"
log "informe enviado ($priority)"
