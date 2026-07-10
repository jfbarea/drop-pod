# Feature: botón de borrar por artículo en el scriptorium

## Contexto

Petición de Fran: un botón de borrar en cada artículo del catálogo. Alcance acordado
(AskUserQuestion): borra **el fichero HTML** de `~/src/html` — a la **Papelera del
Mac**, no `rm` definitivo — y limpia su entrada del mapping de shares si la tenía.
El artifact remoto de claude.ai no se toca (no existe API de borrado; se quita a
mano desde la web si hace falta).

Reutiliza la infraestructura de `scriptorium-share`: el bridge local
`macos/scriptorium-share.py` (127.0.0.1:8737) gana un endpoint de borrado, expuesto
same-origin por la ruta `/-/*` ya existente del Caddyfile (loopback-only, así que
nadie de la LAN puede borrar).

Decisiones de diseño:

- **Papelera**: mover a `~/.Trash/` con `os.rename` (mismo volumen) y sufijo ante
  colisión de nombre. Se descarta `osascript`/Finder: desde un LaunchAgent requiere
  permiso TCC de Automation que puede fallar en silencio. Contra: sin metadatos de
  "volver a colocar" de Finder; aceptable, el fichero es recuperable arrastrándolo.
- **Alcance del borrado**: ficheros regulares bajo `~/src/html` (validación realpath
  como en `/share`, pero sin exigir sufijo `.html`: el catálogo lista otros tipos).
  Nunca directorios ni el mapping interno. Symlinks: se borra el symlink mismo (no
  el destino), nunca un path cuyo padre resuelto caiga fuera de la base.
- **Confirmación en dos pasos** en el visor para evitar borrados por click accidental.

## Hitos

### 1. `delete-endpoint` — POST /delete en el bridge [PENDING]

En `macos/scriptorium-share.py`:

- `POST /delete` body `{"path": "/<rel>"}` — validación de path calcada a la de
  `/share` (realpath bajo `~/src/html`) pero aceptando cualquier fichero regular
  (rechaza directorios, el propio `.scriptorium-shares.json` y sus temporales).
  Mueve el fichero a `~/.Trash/` (sufijo `.deleted-<epoch>` u similar si ya existe
  el nombre allí) y elimina la entrada del mapping si existe (escritura atómica ya
  implementada). Respuestas: 200 `{"trashed": "<ruta en Papelera>"}`, 400 path
  inválido, 404 no existe.
- Sin cambios en Caddyfile (la ruta `/-/*` ya proxya todo), ni en install/test
  (ningún fichero ni symlink nuevo; los checks existentes ya cubren bridge y ruta).

Aceptación:
- `curl -X POST http://localhost:8080/-/delete` con un fichero de prueba → 200, el
  fichero aparece en `~/.Trash/` y desaparece de `~/src/html`; su entrada del
  mapping (sembrada a mano) desaparece; el resto del mapping sobrevive.
- Borrar dos veces un fichero del mismo nombre → sin colisión en la Papelera.
- Directorio, path con traversal, symlink que resuelve fuera, mapping interno,
  inexistente → 400/404 sin efectos.
- Desde IP de LAN → 403 (por el matcher existente).
- `bash test.sh` sigue en verde.

### 2. `catalog-delete-button` — botón por artículo en el catálogo [PENDING]

En `macos/scriptorium-browse.html`:

- Icono de papelera por cada entrada de fichero (no carpetas) del árbol del
  catálogo y de los resultados de búsqueda/paleta si es razonable — como mínimo en
  el árbol. Visible en hover de la entrada (y accesible por teclado), sin romper el
  click de apertura del doc (stopPropagation).
- Dos pasos: primer click convierte el icono en confirmación explícita («¿borrar?»)
  que expira sola a los ~3 s; segundo click ejecuta `POST /-/delete`.
- Éxito: la entrada desaparece del árbol (refresco del listado del directorio padre
  o poda del nodo en memoria); si el doc borrado estaba abierto en el lector, el
  panel vuelve al estado vacío. Si tenía share, el enlace muere con él (el mapping
  ya se limpió en el bridge).
- Error: mensaje breve estilo estados semánticos (mismo patrón que el botón
  compartir), sin romper el visor.
- Estética scriptorium: iconografía y tamaños coherentes con las entradas actuales.

Aceptación:
- Flujo completo en navegador: hover → papelera → confirmar → la entrada desaparece
  y el fichero está en la Papelera del Mac.
- Borrar el doc abierto cierra el lector al estado vacío.
- Un click accidental (sin confirmación) no borra nada y expira solo.
- Con el bridge parado → error visible y visor usable.
- `node --check` del script extraído OK; sin regresiones en compartir/PDF/búsqueda/
  paleta.
