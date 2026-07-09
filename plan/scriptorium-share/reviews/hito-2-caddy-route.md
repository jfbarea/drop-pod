# Review — hito 2: caddy-route

## Veredicto: APPROVED

## Bloqueantes

Ninguno.

## Sugerencias

1. **`hide` con match exacto en vez de glob.** `macos/scriptorium.Caddyfile:38` usa
   `hide .scriptorium-shares.json` (nombre exacto). `save_mapping()` en
   `macos/scriptorium-share.py:66-78` escribe primero a un temporal
   `.scriptorium-shares-<random>.tmp` en el mismo `BASE_DIR` y hace `os.replace`
   atómico — en operación normal ese temporal nunca es visible por HTTP porque el
   rename es atómico. Pero si el proceso muriera entre `mkstemp` y `os.replace`
   (kill -9, panic del intérprete, falta de espacio en disco a mitad de escritura),
   el `.scriptorium-shares-*.tmp` huérfano quedaría en `~/src/html` y sí aparecería
   en el listado del catálogo, porque `hide` con nombre exacto no lo cubre.
   Confirmado empíricamente en un Caddyfile de prueba aislado que `hide` sí admite
   patrones glob (`hide .secret-*.tmp` oculta tanto del listado como del GET
   directo), así que añadir `hide .scriptorium-shares.json .scriptorium-shares-*.tmp`
   cierra ese hueco sin coste. No bloqueante: requiere un crash a mitad de escritura
   para manifestarse, y el propio nombre con punto inicial ya lo aparta de miradas
   casuales.

2. **Comentario del bridge desactualizado en un detalle menor.**
   `macos/scriptorium-share.py:13` dice "El proxy same-origin (/-/*) que lo expone
   al visor lo añade el Caddyfile en un hito posterior" — ese hito posterior es
   este mismo (hito 2), ya aplicado. No afecta a nada funcional, pero conviene
   dejarlo en pasado en el próximo commit que toque el fichero para no confundir
   a quien lo lea después.

## Riesgos

Ninguno nuevo respecto a los ya documentados en la review del hito 1 (alcance de
`Write` en la sesión desatendida de Claude, y exposición del endpoint una vez
colgado de Caddy). Este hito mitiga exactamente el segundo de esos riesgos con el
matcher `not remote_ip 127.0.0.1 ::1`, verificado más abajo.

## Verificación realizada

- Lectura de `plan/scriptorium-share/PLAN.md` (hito 2), `_state.json` y la review
  del hito 1.
- `grep -rn 8081` en el repo: solo quedan referencias históricas dentro de
  comentarios explicativos (`scriptorium-share.py:29`) y de los documentos de plan
  (`_state.json`, review del hito 1), que documentan correctamente el motivo del
  cambio de puerto; no hay ninguna referencia operativa residual a 8081 en código
  o Caddyfile. `grep -rn 8737` confirma el puerto nuevo consistente en
  `scriptorium.Caddyfile`, `scriptorium-share.py` y `scriptorium-share-serve.sh`.
  `com.fran.scriptorium-share.plist` no hardcodea puerto (correcto, no listado en
  `files_changed` de este hito).
- `caddy validate --config macos/scriptorium.Caddyfile --adapter caddyfile` →
  `Valid configuration` (el único warning de formateo, línea 11, es una línea en
  blanco preexistente antes del bloque global, no introducida por este diff).
- `caddy adapt` para inspeccionar el JSON compilado: confirma que el orden real de
  evaluación (independiente del orden textual en el Caddyfile) es
  `vars/header/encode` (no terminal, siempre se ejecuta) → ruta con matcher de
  `path: /-/*` (subroute con `rewrite strip_path_prefix "/-"` +
  `respond @share-not-local 403` + `reverse_proxy`, terminal) → `file_server`
  (catch-all final). Es decir, `handle_path /-/*` sí gana a `file_server` para esa
  ruta por el ordenamiento por defecto de directivas de Caddy, no por casualidad
  de posición en el fichero.
- Matcher `not remote_ip 127.0.0.1 ::1`: confirmado en el JSON que es un matcher
  `remote_ip` (dirección real del socket TCP), no `client_ip` (que sí consultaría
  `X-Forwarded-For` si hubiera `trusted_proxies` configurado). Como no hay ningún
  `trusted_proxies` en este Caddyfile, no existe vector de spoofing vía cabecera
  `X-Forwarded-For`; solo importa la IP real de la conexión. El `Host` header
  tampoco interviene: el bloque `:8080 { ... }` ya respondía a cualquier `Host`
  antes de este cambio, y el matcher de IP no depende de él.
- End-to-end contra el Caddy real del LaunchAgent (symlink al fichero del repo,
  PID 98163) con un bridge de prueba arrancado a mano en 127.0.0.1:8737 y matado al
  terminar:
  - `curl http://localhost:8080/-/shares` → mismo `{}` que `curl 127.0.0.1:8737/shares`.
  - `POST http://localhost:8080/-/share` con path traversal (`/../../etc/passwd`)
    → 400, propagado desde el bridge sin publicar nada.
  - `curl http://localhost:8080/` (listado) y una página `.html` cualquiera → 200,
    el resto del sitio no se ve afectado.
  - Desde la IP de LAN del propio Mac (`192.168.1.16`): `GET /-/shares` → 403;
    `GET /` (mismo origen, misma petición) → 200. Confirma que el bloqueo es
    específico de la ruta `/-/*` y no de la IP en general.
- **Verificación independiente de `hide` que no estaba en las notas del builder**:
  creado `~/src/html/.scriptorium-shares.json` (nombre exacto) con contenido de
  prueba. `GET /.scriptorium-shares.json` directo → **404** (no solo ausente del
  listado: `hide` en Caddy también bloquea el acceso directo al fichero exacto,
  no es una funcionalidad "solo para el listado" como sugiere el comentario del
  Caddyfile). El listado JSON tampoco lo incluye. Esto es estrictamente más
  seguro que el criterio de aceptación pedido (que solo exigía ausencia del
  listado) y no rompe nada: el visor ya no necesita leer ese fichero por HTTP,
  siempre pasa por `/-/shares` vía el bridge. Fichero de prueba eliminado al
  terminar.
- Confirmado en un Caddyfile de prueba aislado (`/tmp`, sin tocar el sistema real)
  que `hide` soporta patrones glob (ver Sugerencia 1); proceso y ficheros de
  prueba eliminados al terminar.
- Estilo: indentación con tabs consistente con el resto del fichero (`cat -A`),
  bloque de comentarios explicativo en el mismo tono que los ya existentes en el
  Caddyfile (que ya documenta decisiones como el Cache-Control `no-cache`).
- Limpieza tras la revisión: sin sesiones/procesos de prueba vivos, sin ficheros
  de prueba en `~/src/html` ni en `/tmp`, Caddy de producción respondiendo 200 en
  `/` al finalizar, LaunchAgent del bridge (`com.fran.scriptorium-share`) sigue sin
  instalar como es esperado hasta el hito 4.

La aceptación del hito 2 está cubierta: `/-/shares` responde igual que el bridge,
`.scriptorium-shares.json` no aparece en el listado (y de propina tampoco es
accesible por GET directo), y el resto del scriptorium sigue funcionando igual
que antes para páginas, listados y accesos desde la LAN.
