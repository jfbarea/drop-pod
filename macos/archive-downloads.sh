#!/usr/bin/env bash
# Archiva en ~/Downloads/archive todo lo de ~/Downloads con más de 7 días de
# antigüedad (mtime). Mueve tanto ficheros sueltos como carpetas de nivel
# superior. Lo ejecuta a diario el LaunchAgent com.fran.archive-downloads.
#
# Uso:
#   archive-downloads.sh            mueve de verdad
#   archive-downloads.sh --dry-run  solo imprime lo que movería, sin tocar nada
#
# Idempotente y seguro:
#   - Excluye la propia carpeta archive (no se re-archiva a sí misma).
#   - Excluye basura del sistema (.DS_Store, .localized).
#   - Excluye "Downloads Policy.txt" (el README de la política, siempre visible).
#   - Ante colisión de nombre en archive, añade un sufijo con epoch.
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY_RUN=1

DOWNLOADS="$HOME/Downloads"
ARCHIVE="$DOWNLOADS/archive"
LOG="$HOME/.local/state/archive-downloads.log"

# Si no hay carpeta Downloads no hay nada que hacer.
[[ -d "$DOWNLOADS" ]] || exit 0

mkdir -p "$(dirname "$LOG")"

# macOS protege ~/Downloads con TCC. Un proceso lanzado por launchd NO hereda
# el permiso de la terminal, así que aquí puede recibir EPERM. Lo detectamos
# por adelantado para fallar con un mensaje claro en vez de archivar 0 en
# silencio (requiere conceder Full Disk Access a /bin/bash en Ajustes).
if ! ls "$DOWNLOADS" >/dev/null 2>&1; then
  echo "ERROR: sin acceso a $DOWNLOADS (concede Full Disk Access a /bin/bash en" \
       "Ajustes → Privacidad y seguridad → Acceso total al disco)" >&2
  exit 1
fi

[[ $DRY_RUN -eq 0 ]] && mkdir -p "$ARCHIVE"

moved=0
# -mindepth/-maxdepth 1: solo el nivel superior de Downloads (no desciende).
# -mtime +7: modificado hace más de 7 días (más de una semana).
# Exclusiones por nombre: la carpeta destino y basura del sistema.
while IFS= read -r -d '' item; do
  base="$(basename "$item")"
  dest="$ARCHIVE/$base"
  # Colisión: no sobrescribir; desambiguar con epoch.
  [[ -e "$dest" ]] && dest="$ARCHIVE/${base}.archived-$(date +%s)"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD MOVE: $item -> $dest"
  else
    mv "$item" "$dest"
  fi
  moved=$((moved + 1))
done < <(
  find "$DOWNLOADS" -mindepth 1 -maxdepth 1 \
    ! -name archive ! -name '.DS_Store' ! -name '.localized' \
    ! -name 'Downloads Policy.txt' \
    -mtime +7 -print0
)

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry-run) $moved elemento(s) se moverían a $ARCHIVE"
else
  echo "$(date -Iseconds) archived=$moved -> $ARCHIVE" >> "$LOG"
fi
