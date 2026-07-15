#!/usr/bin/env bash

pkill -x alerter 2>/dev/null

osascript >/dev/null 2>&1 <<'APPLESCRIPT' &
tell application "System Events"
  repeat with w in windows of process "NotificationCenter"
    try
      repeat with g in UI elements of group 1 of scroll area 1 of group 1 of group 1 of w
        try
          if subrole of g is "AXNotificationCenterAlert" and (value of static text 1 of g) starts with "Claude Code" then
            repeat with a in actions of g
              if description of a is in {"Cerrar", "Close"} then perform a
            end repeat
          end if
        end try
      end repeat
    end try
  end repeat
end tell
APPLESCRIPT

state="$HOME/.claude/hooks/last-notify"
needle="$(cat "$state" 2>/dev/null || true)"
exec "$HOME/.claude/hooks/ghostty-focus.sh" "$needle"
