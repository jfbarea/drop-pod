# Review — hito 1: bridge

## Veredicto: APPROVED

## Bloqueantes

Ninguno.

## Sugerencias

1. **Excepciones no controladas en `do_GET`/`do_POST` producen un reset de conexión en vez de un 5xx JSON.**
   `macos/scriptorium-share.py:178-226`. Hoy solo están cubiertos explícitamente 400/409/502/504 (que coinciden con la aceptación del hito), pero cualquier fallo no anticipado (p. ej. `Content-Length` no numérico, `FileNotFoundError` si `CLAUDE_BIN` no existiera, una `CalledProcessError` de `tmux new-session` por colisión de nombre con otro proceso) escapa sin pasar por `_send_json` y el cliente solo ve la conexión cerrada. Un `try/except Exception` amplio alrededor del cuerpo de `do_POST`/`do_GET` que devuelva `500 {"error": …}` haría el bridge más predecible de depurar. No bloqueante porque no rompe ningún criterio de aceptación probado.

2. **`CLAUDE_BIN` hardcodeado a `~/.local/bin/claude` (línea 36), pero el wrapper valida con `command -v claude` (PATH genérico).**
   Si `claude` se reinstalara en otra ubicación distinta a `~/.local/bin` (p. ej. vía Homebrew), la precondición del wrapper (`scriptorium-share-serve.sh:17`) pasaría igualmente pero el `subprocess.run` fallaría en runtime con la excepción no controlada del punto 1. Usar `shutil.which("claude")` con fallback al path fijo sería más consistente con el propio wrapper.

3. **Puerto 8081 ya está ocupado por otro proceso (`node`, `sunproxyadmin`) en este Mac, aunque en interfaz distinta (`*` vs `127.0.0.1`).**
   Comprobado con `lsof`: ambos coexisten hoy porque uno escucha en wildcard y el bridge en loopback explícito, pero es una coincidencia frágil (si ese otro proceso alguna vez se restringe a `127.0.0.1:8081`, el LaunchAgent del bridge no podrá bindear). Vale la pena documentarlo o, más simple, elegir un puerto con menos probabilidad de colisión.

4. **`tmux_kill_session` en el `finally` de `publish()` (línea 160) se ejecuta incluso si `subprocess.run(tmux_cmd, check=True)` falla por una condición de carrera entre dos instancias del bridge corriendo a la vez** (p. ej. tras un reload manual solapado con el LaunchAgent). En ese escenario podría matar una sesión recién creada por el otro proceso. Es un edge case de doble-instancia que no debería darse en operación normal (un único LaunchAgent), así que lo dejo como nota, no como bloqueante.

## Riesgos

1. **Alcance del tool `Write` combinado con `CLAUDE_CWD = ~/drop-pod` (línea 50).** La sesión de Claude que publica el artifact tiene `--allowedTools "Artifact,Read,Write"` y corre desatendida en tmux (sin humano supervisando, a diferencia del uso interactivo normal). El prompt instruye a Claude a leer el `.html`, publicarlo y escribir solo el resultfile — pero si el contenido de ese `.html` llevara una inyección de prompt, el modelo tiene permiso amplio de `Write` con cwd en el propio repo de dotfiles activo. Hoy el riesgo real es bajo porque `~/src/html` solo lo puebla Fran con sus propios docs generados (no hay una vía para que un tercero deposite HTML arbitrario ahí sin ya tener otro compromiso previo), y el bridge solo escucha en loopback — pero merece quedar documentado explícitamente como riesgo aceptado en el PLAN, y conviene revisar si `--permission-mode`/scoping más estrecho de `Write` es viable antes de que el hito 2 exponga el endpoint a la LAN vía Caddy.
2. **Exposición futura.** El bridge en sí es correcto (solo loopback, verificado que no responde por la IP de LAN), pero en cuanto el hito 2 lo cuelgue detrás de Caddy en `/-/share`, cualquiera en la LAN con acceso a `http://scriptorium` podrá disparar publicaciones de cualquier doc ya existente bajo `~/src/html` (son solo docs propios, pero conviene tenerlo en cuenta al diseñar esa ruta).

## Verificación realizada

- Lectura de `plan/scriptorium-share/PLAN.md` (hito 1) y `_state.json`.
- Lectura completa de `macos/scriptorium-share.py`, `macos/scriptorium-share-serve.sh`, `macos/com.fran.scriptorium-share.plist`, comparados con `macos/scriptorium-serve.sh` y `macos/com.fran.scriptorium.plist` existentes (mismo patrón: PATH de Homebrew, `RunAtLoad`+`KeepAlive`, resolución de `$HOME` vía bash en el plist, logs en `/tmp`).
- **Inyección vía tmux**: reproducido el vector real (`tmux new-session -d -s <name> -c <cwd> <argv...>` construido con `subprocess.run` en modo lista, sin `shell=True`) con un binario señuelo que vuelca su `argv`. Confirmado empíricamente que tmux ejecuta el programa con el `argv` literal (sin re-tokenizar ni pasar por `/bin/sh -c`) cuando se le pasan varios argumentos separados como aquí — un prompt con `$(...)`, backticks o `;` no se ejecuta como shell. No hay inyección de comandos por esta vía.
- **Symlink escape**: creado `~/src/html/evil-symlink.html` → `/tmp/outside-basedir/secret.html` (fuera de `BASE_DIR`) y `~/src/html/evil-hosts.html` → `/etc/hosts`. Ambos POST devuelven 400 — confirma que `resolve_shared_path` resuelve el symlink (`.resolve()`) **antes** de comprobar el prefijo `BASE_DIR` y antes de comprobar el sufijo `.html`, en el orden correcto.
- **Path traversal** (`/../../../../etc/passwd`), **fichero inexistente**, **no-`.html`** (`.txt`), **JSON inválido**, **campo `path` ausente**: todos devuelven 400 con mensaje claro.
- **Bind loopback**: confirmado con `lsof` que el proceso Python escucha en `localhost:8081`, no en `0.0.0.0`; una petición a la IP de LAN de la máquina no llega al bridge (coincide con otro proceso ya ocupando ese puerto en wildcard, ver Sugerencia 3).
- `GET /shares` devuelve el mapping (`{}` en vacío) y rutas no reconocidas devuelven 404 limpio.
- Limpieza: eliminados los symlinks/ficheros de prueba en `~/src/html`, el directorio temporal fuera de `BASE_DIR`, matado el proceso del bridge de prueba; no quedaron sesiones tmux (`tmux ls` → "no server running") ni resultfiles huérfanos. No se publicó ningún artifact real (no se llegó a invocar `publish()` en ningún caso, todas las pruebas fallan en la validación de path, previa al lanzamiento de tmux/claude).

No se pudo re-verificar independientemente la publicación real end-to-end (habría consumido una sesión de Claude); se acepta la evidencia aportada por el builder en `_state.json` (URL real, re-share con misma URL, persistencia, 409 de concurrencia real, 502 de sesión muerta).

La aceptación del hito 1 está cubierta: 400/409/502/504 con mensaje, limpieza de tmux/resultfile en todos los caminos, mapping persistido, y bind exclusivo a loopback.
