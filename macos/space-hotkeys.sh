#!/usr/bin/env bash
# Deja ctrl+1..ctrl+9 saltando al escritorio N en la pantalla principal:
# crea los escritorios que falten y activa los atajos de Mission Control.
set -euo pipefail

DESKTOPS="${1:-9}"

CTRL=262144
# Terceto (ascii, keycode ANSI, modificador) que espera symbolichotkeys. El
# keycode no sigue el orden de los dígitos: 5 es 23 y 6 es 22, no al revés.
KEYCODES=(18 19 20 21 23 22 26 28 25)
# "Switch to Desktop N" es el hotkey simbólico 117+N (118 = escritorio 1).
FIRST_HOTKEY=117

log()  { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

ensure_desktops() {
  if ! command -v hs >/dev/null 2>&1 || ! pgrep -xq Hammerspoon; then
    warn "Hammerspoon no disponible: crea a mano los escritorios que falten hasta $DESKTOPS"
    return 0
  fi

  local uuid current
  uuid="$(hs -c 'return hs.screen.mainScreen():getUUID()' 2>/dev/null | tail -1)"
  current="$(hs -c "return #hs.spaces.allSpaces()['$uuid']" 2>/dev/null | tail -1)"

  if [[ ! "$current" =~ ^[0-9]+$ ]]; then
    warn "No se pudo contar los escritorios de la pantalla principal"
    return 0
  fi

  if (( current >= DESKTOPS )); then
    log "Escritorios: $current (≥ $DESKTOPS), nada que crear"
    return 0
  fi

  local n
  for (( n = current + 1; n <= DESKTOPS; n++ )); do
    hs -c "hs.spaces.addSpaceToScreen('$uuid', false)" >/dev/null 2>&1
  done
  log "Escritorios: $current → $DESKTOPS"
}

hotkey_matches() {
  local id="$1" keycode="$2" ascii="$3"
  defaults export com.apple.symbolichotkeys - 2>/dev/null \
    | plutil -convert json -o - - 2>/dev/null \
    | jq -e --arg id "$id" --argjson kc "$keycode" --argjson a "$ascii" --argjson m "$CTRL" '
        .AppleSymbolicHotKeys[$id]
        | .enabled == true and .value.parameters == [$a, $kc, $m]
      ' >/dev/null 2>&1
}

ensure_hotkeys() {
  local changed=0 n id keycode ascii
  for (( n = 1; n <= 9; n++ )); do
    id=$(( FIRST_HOTKEY + n ))
    keycode="${KEYCODES[n-1]}"
    ascii=$(( 48 + n ))

    if hotkey_matches "$id" "$keycode" "$ascii"; then
      continue
    fi

    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" "
      <dict>
        <key>enabled</key><true/>
        <key>value</key>
        <dict>
          <key>type</key><string>standard</string>
          <key>parameters</key>
          <array>
            <integer>$ascii</integer>
            <integer>$keycode</integer>
            <integer>$CTRL</integer>
          </array>
        </dict>
      </dict>"
    changed=1
  done

  if (( changed == 0 )); then
    log "Atajos ctrl+1..9 ya activos"
    return 0
  fi

  # Sin esto el Dock sigue con los atajos viejos hasta el siguiente login.
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  log "Atajos ctrl+1..9 activados"
}

ensure_desktops
ensure_hotkeys
