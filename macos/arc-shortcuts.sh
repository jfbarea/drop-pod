#!/usr/bin/env bash
set -euo pipefail

DOMAIN=company.thebrowser.Browser
changed=0

log() { printf '  %s\n' "$*"; }

ensure_shortcut() {
  local item="$1" keys="$2" current
  current="$(defaults export "$DOMAIN" - 2>/dev/null \
    | plutil -extract "NSUserKeyEquivalents.$item" raw -o - - 2>/dev/null || true)"
  [[ "$current" == "$keys" ]] && return 0
  # -dict-add conserva el resto de atajos de Arc que haya puestos a mano. El
  # valor va entre comillas: sin ellas defaults falla con "Could not parse: @[".
  defaults write "$DOMAIN" NSUserKeyEquivalents -dict-add "$item" "\"$keys\""
  changed=1
}

ensure_shortcut "Previous Space" '@['
ensure_shortcut "Next Space" '@]'

if (( changed == 0 )); then
  log "Atajos cmd+[ / cmd+] de Arc ya activos"
else
  log "Atajos cmd+[ / cmd+] de Arc activados (reinicia Arc para aplicarlos)"
fi
