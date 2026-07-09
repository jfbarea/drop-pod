# Review — hito 4: install-test

## Veredicto: APPROVED

## Bloqueantes

Ninguno.

## Sugerencias

1. **Los dos checks de red de la sección 7d (`bridge responde en .../shares` y
   `proxy same-origin ... vía Caddy`) dependen de que el LaunchAgent ya esté
   arrancado y respondiendo en el instante exacto en que corre `test.sh`.**
   `test.sh:191-194`. No hay retry/backoff. En la práctica el arranque del
   bridge (Python stdlib, sin dependencias) es prácticamente instantáneo tras
   `launchctl load -w`, y así lo confirmé ejecutando `install.sh`→`test.sh` en
   secuencia sin fallos, pero si algún día el bridge tardara más en arrancar
   (p. ej. tras añadir alguna inicialización costosa) este check podría dar un
   falso negativo justo después de una instalación en frío. No bloqueante: es
   coherente con el nivel de rigor que ya pide este hito, y el propio check de
   `launchctl list | grep -q com.fran.scriptorium-share` (línea 190) ya cubre el
   caso de que el LaunchAgent ni siquiera esté cargado.
2. **La sección "macOS — scriptorium" (7c) no tiene un check HTTP equivalente
   para `:8080`** (solo comprueba binario, symlinks y `LaunchAgent cargado` vía
   `launchctl list`), mientras que la nueva sección 7d sí añade curls reales al
   bridge y al proxy. Es una asimetría de rigor entre secciones hermanas
   preexistente-vs-nueva, no un defecto introducido por este hito — al
   contrario, 7d eleva el nivel. Simple nota para una futura pasada de
   consistencia, no accionable ahora.

## Riesgos

Ninguno nuevo. Los riesgos de fondo (alcance de `Write` en la sesión desatendida
de `claude`, endpoint expuesto a la LAN aunque protegido por IP) ya están
documentados en las reviews de los hitos 1 y 2; este hito no cambia esa
superficie, solo la instalación/verificación del stack ya aprobado.

## Verificación realizada

- Lectura de `plan/scriptorium-share/PLAN.md` (hito 4), `_state.json` (evidencia
  del builder) y `git diff -- install.sh test.sh`.
- **`install.sh` línea a línea**: `setup_scriptorium_share()` (líneas 466-491)
  es una copia estructural fiel de `setup_scriptorium()` (líneas 428-464, ya
  aprobada y en producción): mismo patrón `chmod +x` sobre el wrapper fuente →
  tres `safe_link` → `launchctl unload ... || true` seguido de
  `launchctl load -w` con `ok`/`warn` según resultado. No hay ninguna acción sin
  guard: `chmod +x` es idempotente por naturaleza, `safe_link` delega en
  `backup_if_needed` (comparte código con todos los symlinks del repo, no se
  tocó), y el ciclo `unload||true` + `load -w` es el mismo patrón ya usado por
  `setup_scriptorium`/`setup_archive_downloads`.
- **Coherencia plist ↔ symlinks ↔ wrapper**: abiertos los tres ficheros.
  `macos/com.fran.scriptorium-share.plist` invoca
  `$HOME/.local/bin/scriptorium-share-serve.sh` (línea 13) — coincide con
  `script_dst` en `install.sh:474`. `scriptorium-share-serve.sh` define
  `SCRIPT="$HOME/.local/bin/scriptorium-share.py"` (línea 13 del wrapper) —
  coincide con `bridge_dst` en `install.sh:472`. Las tres rutas cuadran entre sí
  y con los tres `check_symlink` nuevos de `test.sh:182-188`.
- **Orden del `run_step`**: `run_step "scriptorium-share" setup_scriptorium_share`
  (`install.sh:549`) se ejecuta justo después de
  `run_step "scriptorium" setup_scriptorium` (línea 544) y antes de
  `git-remote`/`claude-template`. Coherente con la dependencia lógica (el
  Caddyfile con la ruta `/-/*` ya lo enlaza `setup_scriptorium`), y cada
  `run_step` corre aislado (subshell con `set -euo pipefail`), así que un fallo
  en uno no bloquea al otro.
- **Reglas de `test.sh` del `CLAUDE.md` del repo**: symlinks nuevos →
  `check_symlink` de los tres destinos (líneas 182-188, cubierto). Nuevo
  agente/comando de Claude Code → no aplica a este hito. Nuevo campo de
  `settings.json` → no aplica. Nueva función de shell en el rc → no aplica
  (esto vive en `install.sh`, no en el rc). Cubre además, más allá de lo mínimo
  exigido por el `CLAUDE.md`, el binario ejecutable del wrapper y el contenido
  del Caddyfile (`/-/*` y `hide`), en línea con lo pedido explícitamente por el
  propio hito 4 del `PLAN.md`.
- **Patrones `grep` de los dos checks de contenido del Caddyfile**: verificados
  contra el fichero real. `grep -q 'handle_path /-/\*'` — el `\*` escapa el
  asterisco a literal en BRE (sin escapar significaría "cero o más del carácter
  anterior" y matchearía casi cualquier cosa); está bien escapado. `grep -q
  'hide .scriptorium-shares.json'` — el `.` sin escapar hace de comodín de un
  carácter, pero como también matchea el punto literal real, no hay falso
  negativo; estilo consistente con otros checks de contenido ya existentes
  (p. ej. `grep -q 'function exportPdf'` en la sección 7c).
- **Ejecución real, sin tocar nada a mano**: `bash test.sh` completo →
  **116 pasados, 0 fallidos, 0 omitidos**, incluidos los 9 checks nuevos de la
  sección "macOS — scriptorium-share", todos en verde.
- **Estado del sistema tras la instalación real del builder** (sin volver a
  correr `install.sh` yo mismo — no era necesario: la idempotencia de la
  función nueva ya queda acreditada por ser una copia estructural de
  `setup_scriptorium`, cuya idempotencia ya está probada en producción, y el
  builder aportó el diff línea a línea entre la 2ª y 3ª pasada):
  - `launchctl list | grep scriptorium` → `com.fran.scriptorium-share` y
    `com.fran.scriptorium` cargados con PID activo.
  - `tmux ls` → "no server running" (sin sesiones `scriptorium-share`
    huérfanas).
  - `~/src/html/.scriptorium-shares.json` → `{}` (mapping limpio, sin la
    entrada `drop-pod/test-hito4.html` de la publicación real de prueba del
    builder).
  - Sin ficheros `*hito4*`/`*test-hito4*` residuales bajo `~/src/html`.
  - Sin `resultfile`/directorio huérfano en `/tmp/scriptorium-share`.
- Nota sobre el quirk de `safe_link`/`backup_if_needed` con symlinks absolutos
  (re-emite el warning "Replacing stale/absolute symlink" en cada pasada): es
  un comportamiento preexistente y ya aceptado (afecta igual a
  `setup_scriptorium` desde antes de esta feature), no introducido ni agravado
  por este hito. El estado final en disco es estable pasada a pasada, que es lo
  que exige la aceptación del hito.

La aceptación del hito 4 está cubierta: `install.sh` amplía el patrón existente
de forma idempotente y con las rutas coherentes entre plist/wrapper/script, y
`test.sh` incorpora los 9 checks pedidos (symlinks, ejecutable, LaunchAgent,
bridge, proxy y contenido del Caddyfile), verificados en verde de forma
independiente.
