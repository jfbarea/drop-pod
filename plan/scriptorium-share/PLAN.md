# Feature: botón «Compartir» del scriptorium → Artifact de claude.ai

## Contexto

El visor del scriptorium (`macos/scriptorium-browse.html`) tiene un botón de PDF en la
docbar. Se añade un botón «Compartir» que publica la página abierta como Artifact de
claude.ai y muestra/copia su URL, para compartir docs con el equipo por enlace.

Restricción validada (docs oficiales + prueba local): la herramienta `Artifact` solo
existe en sesiones **interactivas** de Claude Code — no en `claude -p`, ni en el Agent
SDK, ni hay API pública de creación. Por eso el botón habla con un bridge local que
lanza una sesión interactiva de `claude` dentro de tmux (detached, sin ventana).

Diseño acordado con Fran (opción «puente tmux invisible»):

- Click → spinner en el visor → URL en la docbar + portapapeles (~30–90 s).
- Re-compartir un doc actualiza el **mismo** artifact (misma URL), vía el parámetro
  `url` del tool y un mapping persistido.
- Una publicación a la vez; segundo click concurrente recibe 409.

## Arquitectura

```
visor (:8080) ── POST /-/share ──▶ Caddy ── reverse_proxy ──▶ bridge (127.0.0.1:8737)
                                                                │
                                                                ├─ tmux new-session -d: claude interactivo
                                                                │    --allowedTools "Artifact,Read,Write"
                                                                │    prompt: publica <abs>.html como Artifact
                                                                │            (con url=<existente> si re-share)
                                                                │            y escribe {"url"} en <resultfile>
                                                                ├─ poll resultfile → kill sesión tmux
                                                                └─ mapping ~/src/html/.scriptorium-shares.json
```

Ficheros nuevos: `macos/scriptorium-share.py` (bridge, Python3 stdlib, sin deps),
`macos/scriptorium-share-serve.sh` (wrapper estilo `scriptorium-serve.sh`),
`macos/com.fran.scriptorium-share.plist` (LaunchAgent). Modificados:
`macos/scriptorium.Caddyfile`, `macos/scriptorium-browse.html`, `install.sh`, `test.sh`.

## Hitos

### 1. `bridge` — bridge HTTP + publicación vía tmux/claude [PENDING]

`macos/scriptorium-share.py` escuchando SOLO en 127.0.0.1:8737, más wrapper y plist
(patrón `com.fran.scriptorium`: PATH de Homebrew, RunAtLoad, KeepAlive).

- `POST /share` body `{"path": "/<rel>.html"}` — valida que el path resuelto
  (realpath) cae bajo `~/src/html` y termina en `.html`; si no, 400. Lanza la sesión
  tmux (nombre fijo `scriptorium-share`), espera el resultfile (long-poll, timeout
  180 s), mata la sesión, persiste el mapping y responde `{"url": …}`. Si ya hay una
  sesión con ese nombre → 409. Timeout o sesión muerta sin resultado → 504/502 con
  mensaje.
- `GET /shares` — devuelve el mapping `rel-path → {url, sharedAt}` de
  `~/src/html/.scriptorium-shares.json`.
- La sesión claude corre con `--allowedTools "Artifact,Read,Write"` y un prompt que:
  publica el HTML como Artifact (si el mapping ya tiene URL para ese path, la pasa
  como `url` para actualizar en sitio), escribe `{"url": "…"}` en el resultfile y
  nada más. Modelo configurable en una variable del script (empezar con haiku por
  coste; si en la verificación interactiva no expone Artifact, subir al por defecto).
- Cuestión a resolver empíricamente en este hito: diálogo de confianza de directorio
  en el primer arranque de claude (elegir cwd ya confiable o documentar
  `tmux attach -t scriptorium-share` como desbloqueo la primera vez).

Aceptación (verificable, con publicación REAL):
- `curl -X POST 127.0.0.1:8737/share -d '{"path": "/<doc>.html"}'` devuelve una URL
  `https://claude.ai/…` que abre y renderiza el doc.
- Repetir el POST del mismo path devuelve la MISMA URL (artifact actualizado).
- `GET /shares` refleja el mapping persistido; sobrevive a reiniciar el bridge.
- POST mientras hay otro en curso → 409. Path con traversal o no-`.html` → 400.
- Tras cada petición (éxito, error o timeout) no queda sesión tmux
  `scriptorium-share` viva ni resultfile huérfano.

### 2. `caddy-route` — proxy same-origin en el Caddyfile [PENDING]

En `macos/scriptorium.Caddyfile`: `handle_path /-/*` → `reverse_proxy 127.0.0.1:8737`,
y `hide` del `.scriptorium-shares.json` en el `file_server` para que no salga en el
catálogo.

Aceptación:
- `curl http://localhost:8080/-/shares` devuelve el mismo JSON que el bridge.
- El listado JSON de browse en `/` no incluye `.scriptorium-shares.json`.
- El resto del scriptorium sigue funcionando (páginas y listados como antes).

### 3. `viewer-button` — botón «Compartir» en la docbar [PENDING]

En `macos/scriptorium-browse.html`, junto al botón PDF, solo para `.html`:

- Estados: reposo («compartir») → «publicando…» con spinner y botón deshabilitado →
  éxito: «✓ copiado» + enlace a la URL del artifact (clipboard vía
  `navigator.clipboard`, con fallback silencioso) → error: mensaje breve en la
  docbar sin romper el visor.
- Al abrir un doc, consulta el mapping (`GET /-/shares`, cacheado por sesión de
  página) y si ya está compartido muestra el enlace directamente; el botón pasa a
  «actualizar».
- Estética scriptorium: mismos estilos que los botones existentes de la docbar.

Aceptación:
- Con bridge y Caddy vivos, flujo completo desde el navegador: click → spinner →
  enlace visible y URL en portapapeles.
- Abrir un doc ya compartido muestra su enlace sin clicks.
- Con el bridge parado, el click muestra error y el visor sigue usable.

### 4. `install-test` — instalación idempotente y checks [PENDING]

- `install.sh`: ampliar `setup_scriptorium` (o función hermana) con `safe_link` de
  los tres ficheros nuevos, `chmod +x` del wrapper y recarga idempotente del
  LaunchAgent `com.fran.scriptorium-share`, siguiendo el patrón existente.
- `test.sh` (reglas del CLAUDE.md del repo): `check_symlink` de los tres destinos
  nuevos, check de que el bridge responde en 127.0.0.1:8737 (`/shares`), y check de
  que el Caddyfile contiene la ruta `/-/`.

Aceptación:
- Ejecutar `bash install.sh` dos veces seguidas: segunda pasada sin cambios ni errores.
- `bash test.sh` en verde, incluidos los checks nuevos.

### 5. `hide-link-until-shared` — el enlace «artifact» no debe verse sin artifact [PENDING]

Feedback de HUMAN_REVIEW (Fran): el enlace «artifact» de la docbar aparece antes de
que exista el artifact y lleva a error. Causa: `.docbar a{display:inline-flex}`
(estilos de autor) anula la regla UA `[hidden]{display:none}`, así que el atributo
`hidden` de `#share-link` no oculta nada.

- Arreglar en el CSS del visor (p. ej. `.docbar a[hidden]{display:none}`) de forma
  que el enlace solo se vea cuando `link.hidden = false` (doc ya compartido o
  publicación con éxito).
- Repasar que ningún otro uso de `hidden` en el visor sufra el mismo choque.

Aceptación:
- Doc sin compartir: el enlace «artifact» no se ve; tras publicar, aparece; doc ya
  compartido lo muestra al abrirse. Verificado sobre el DOM real (no solo a ojo).
- Sin regresiones en los estados del botón (reposo/publicando/✓ copiado/error).
