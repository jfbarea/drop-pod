#!/usr/bin/env bash
# Sirve ~/src/html en http://localhost:8080 vía Caddy, con listado de
# directorios. Lo mantiene vivo el LaunchAgent com.fran.scriptorium
# (RunAtLoad + KeepAlive), así que corre en segundo plano todo el rato.
#
# El acceso por http://scriptorium (puerto 80) lo habilita aparte, con sudo,
# scriptorium-root-setup.sh (entrada en /etc/hosts + redirección pf 80->8080).
set -euo pipefail

# launchd arranca con un PATH mínimo que no incluye Homebrew; lo añadimos para
# encontrar el binario caddy tanto en Apple Silicon como en Intel.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CADDYFILE="$HOME/.config/caddy/scriptorium.Caddyfile"

command -v caddy >/dev/null || { echo "ERROR: caddy no está en PATH" >&2; exit 1; }
[[ -f "$CADDYFILE" ]] || { echo "ERROR: no existe $CADDYFILE" >&2; exit 1; }

exec caddy run --config "$CADDYFILE" --adapter caddyfile
