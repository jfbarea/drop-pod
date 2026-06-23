#!/usr/bin/env bash
# Habilita http://bibliotecario (puerto 80) en este Mac. Ejecutar UNA vez con
# sudo; install.sh ya deja corriendo el servidor Caddy de usuario en :8080.
#
#   sudo bash macos/bibliotecario-root-setup.sh
#
# Hace tres cosas a nivel de sistema (por eso requiere root); todas idempotentes:
#   1. Resuelve el nombre `bibliotecario` a 127.0.0.1 en /etc/hosts.
#   2. Instala una regla pf que redirige el puerto 80 -> 8080 en loopback
#      (el Caddy de usuario escucha en 8080, sin privilegios).
#   3. Instala un LaunchDaemon que recarga esa regla pf en cada arranque y la
#      aplica ya.
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "Solo para macOS." >&2; exit 1; }
[[ "$EUID" -eq 0 ]] || { echo "Ejecútame con sudo: sudo bash $0" >&2; exit 1; }

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIAS="bibliotecario"

# 1. /etc/hosts ───────────────────────────────────────────────────────────────
if grep -qE "^[^#]*[[:space:]]${ALIAS}([[:space:]]|$)" /etc/hosts; then
  echo "✓ /etc/hosts ya resuelve ${ALIAS}"
else
  printf '127.0.0.1\t%s\n' "$ALIAS" >> /etc/hosts
  echo "✓ Añadido ${ALIAS} -> 127.0.0.1 en /etc/hosts"
fi

# 2. Regla pf 80 -> 8080 ───────────────────────────────────────────────────────
install -m 644 "$DOTFILES/macos/bibliotecario.pf.anchor" /etc/pf.anchors/bibliotecario
install -m 644 "$DOTFILES/macos/bibliotecario-pf.conf"   /etc/pf-bibliotecario.conf
echo "✓ Instalada regla pf (puerto 80 -> 8080)"

# 3. LaunchDaemon que recarga pf al arrancar ───────────────────────────────────
daemon=/Library/LaunchDaemons/com.fran.bibliotecario-pf.plist
install -m 644 -o root -g wheel "$DOTFILES/macos/com.fran.bibliotecario-pf.plist" "$daemon"
launchctl unload "$daemon" 2>/dev/null || true
launchctl load -w "$daemon"
echo "✓ LaunchDaemon de pf cargado"

# Aplica la redirección ya, sin esperar al próximo arranque.
# pfctl -e devuelve != 0 si pf ya estaba activo; no es un error.
pfctl -ef /etc/pf-bibliotecario.conf 2>/dev/null || true
echo "✓ Redirección activa. Abre: http://${ALIAS}"
