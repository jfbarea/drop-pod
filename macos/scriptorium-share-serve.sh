#!/usr/bin/env bash
# Sirve el bridge de compartir del scriptorium (POST /share, GET /shares) en
# 127.0.0.1:8737. Lo mantiene vivo el LaunchAgent com.fran.scriptorium-share
# (RunAtLoad + KeepAlive). Solo escucha en localhost: el visor lo alcanza a
# través del proxy same-origin /-/* que añade macos/scriptorium.Caddyfile.
set -euo pipefail

# launchd arranca con un PATH mínimo que no incluye Homebrew ni ~/.local/bin;
# los añadimos para encontrar tmux, python3 y claude tanto en Apple Silicon
# como en Intel.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

SCRIPT="$HOME/.local/bin/scriptorium-share.py"

command -v tmux >/dev/null || { echo "ERROR: tmux no está en PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 no está en PATH" >&2; exit 1; }
command -v claude >/dev/null || { echo "ERROR: claude no está en PATH" >&2; exit 1; }
[[ -f "$SCRIPT" ]] || { echo "ERROR: no existe $SCRIPT" >&2; exit 1; }

exec python3 "$SCRIPT"
