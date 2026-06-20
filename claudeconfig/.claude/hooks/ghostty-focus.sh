#!/usr/bin/env bash
# Activa Ghostty y eleva la ventana cuyo título contiene la cadena dada.
# Lo invoca terminal-notifier (-execute) al pinchar la notificación en macOS.
# Uso: ghostty-focus.sh <substring-del-título>
#
# Requiere permiso de Accesibilidad para System Events (la primera vez macOS
# lo pedirá). Si no encuentra la ventana, deja Ghostty al frente igualmente.

needle="${1:-}"

osascript - "$needle" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set needle to item 1 of argv
  tell application "Ghostty" to activate
  if needle is "" then return
  tell application "System Events"
    tell process "Ghostty"
      repeat with w in windows
        try
          if (name of w) contains needle then
            perform action "AXRaise" of w
            exit repeat
          end if
        end try
      end repeat
    end tell
  end tell
end run
APPLESCRIPT
