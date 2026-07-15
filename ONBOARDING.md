# Scriptorium — montarlo en tu Mac

Guía para que Claude Code instale un **scriptorium** propio: un servidor web
local (Caddy) que sirve `~/src/html` con un catálogo navegable y un panel
lector, pensado para que Claude Code deposite ahí los HTML que genera
(research, reviews, audits, dashboards…) y tú los leas, exportes a PDF o
compartas como Artifacts de claude.ai.

Origen: dotfiles de Fran, repo público `https://github.com/jfbarea/drop-pod`
(directorio `macos/`). Esta guía **no** instala esos dotfiles: solo extrae las
piezas del scriptorium y las adapta a la máquina del usuario.

## Qué se monta

1. **Núcleo** (siempre): Caddy sirviendo `~/src/html` en `http://localhost:8080`,
   con el visor-catálogo `scriptorium-browse.html` como plantilla de listado,
   mantenido vivo por un LaunchAgent.
2. **Nombre bonito** (opcional, requiere sudo): `http://scriptorium` en el
   puerto 80, vía entrada en `/etc/hosts` + regla pf 80→8080 + LaunchDaemon.
3. **Bridge de compartir/borrar** (opcional): servicio local en
   `127.0.0.1:8737` que da al visor el botón «compartir» (publica el doc como
   Artifact de claude.ai usando la sesión de Claude Code del usuario) y el de
   papelera (mueve el doc a `~/.Trash`). Requiere `tmux` y el CLI `claude`.
4. **Convenciones de Claude** (siempre): sección «Output en HTML» en el
   `~/.claude/CLAUDE.md` del usuario, para que su Claude genere los HTML en
   `~/src/html/<repo>/` con el estilo de la casa y rote los viejos a `archive/`.

## Instrucciones para Claude Code

Ejecuta los pasos en orden. Todo debe ser idempotente: comprueba antes de
instalar/copiar/cargar. Pregunta al usuario solo lo marcado como opcional.

### 0. Requisitos

- macOS (esta guía es macOS-only; aborta en otro SO explicándolo).
- Homebrew instalado (`command -v brew`).
- Caddy: `command -v caddy || brew install caddy`.

### 1. Obtener los ficheros

Clona el repo a un directorio temporal (no hace falta conservarlo):

```bash
git clone --depth 1 https://github.com/jfbarea/drop-pod /tmp/drop-pod-scriptorium
```

Los ficheros a **copiar** (copiar, no symlink — el clon es desechable) desde
`/tmp/drop-pod-scriptorium/macos/`:

| Origen | Destino |
|---|---|
| `scriptorium.Caddyfile` | `~/.config/caddy/scriptorium.Caddyfile` |
| `scriptorium-browse.html` | `~/.config/caddy/scriptorium-browse.html` |
| `scriptorium-serve.sh` | `~/.local/bin/scriptorium-serve.sh` (chmod +x) |
| `com.fran.scriptorium.plist` | `~/Library/LaunchAgents/com.fran.scriptorium.plist` |

Crea antes los directorios (`~/src/html`, `~/.config/caddy`, `~/.local/bin`,
`~/Library/LaunchAgents`). Mantén los nombres `com.fran.*` de los plists: son
solo etiquetas y así los checks y la documentación del repo original siguen
valiendo.

### 2. Arrancar el núcleo

```bash
launchctl unload ~/Library/LaunchAgents/com.fran.scriptorium.plist 2>/dev/null || true
launchctl load -w ~/Library/LaunchAgents/com.fran.scriptorium.plist
```

Verifica: `curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/` debe
devolver 200. Si falla, mira `/tmp/com.fran.scriptorium.err` (el error típico
es `caddy` fuera del PATH de launchd; el wrapper ya añade las rutas de
Homebrew de Apple Silicon e Intel).

Nota de red: el Caddyfile escucha en `:8080` en **todas las interfaces**
(cualquiera en tu misma red puede ver `~/src/html`). Si el usuario trabaja en
redes no confiables, ofrécele cambiar `:8080` por `127.0.0.1:8080` en
`~/.config/caddy/scriptorium.Caddyfile` — no rompe nada más (la redirección
del puerto 80 es sobre loopback).

### 3. Opcional: `http://scriptorium` (puerto 80)

Pregunta al usuario si lo quiere (requiere sudo). Si sí:

```bash
sudo bash /tmp/drop-pod-scriptorium/macos/scriptorium-root-setup.sh
```

Es idempotente: añade `scriptorium → 127.0.0.1` a `/etc/hosts`, instala la
regla pf 80→8080 y un LaunchDaemon que la recarga en cada arranque. Copia
ficheros a rutas del sistema, así que no depende del clon temporal después.

### 4. Opcional: bridge de compartir y papelera

Pregunta al usuario si quiere el botón «compartir» (publica docs como
Artifacts con SU cuenta de claude.ai) y el de papelera. Si sí:

- Requisitos: `command -v tmux || brew install tmux`, y el CLI `claude`
  instalado y con sesión iniciada.
- Copia desde el clon: `scriptorium-share.py` → `~/.local/bin/`,
  `scriptorium-share-serve.sh` → `~/.local/bin/` (chmod +x),
  `com.fran.scriptorium-share.plist` → `~/Library/LaunchAgents/`.
- **Personaliza `~/.local/bin/scriptorium-share.py`** (dos constantes pensadas
  para la máquina original):
  - `CLAUDE_BIN`: ruta real del binario (`command -v claude`); el valor por
    defecto es `~/.local/bin/claude`.
  - `CLAUDE_CWD`: un directorio que el usuario ya tenga **confiado** en Claude
    Code (p. ej. su repo principal). Si apunta a un directorio no confiado, la
    sesión tmux se queda bloqueada en el diálogo de confianza y las
    publicaciones expiran con timeout.
- Carga el LaunchAgent (mismo patrón unload/load que el núcleo) y verifica:
  `curl -s http://127.0.0.1:8737/shares` devuelve JSON, y
  `curl -s http://localhost:8080/-/shares` devuelve lo mismo (proxy del visor).

Notas para contarle al usuario: cada publicación lanza una sesión efímera de
`claude` en tmux (~30–90 s, una a la vez) con su cuenta; re-compartir un doc
actualiza el mismo artifact (misma URL); la papelera mueve a `~/.Trash`, no
borra el artifact remoto. El bridge escucha solo en loopback y el proxy
`/-/*` del Caddyfile rechaza peticiones que no vengan del propio Mac.

Si el usuario no quiere el bridge, no pasa nada: el visor funciona igual y los
botones de compartir/papelera simplemente mostrarán error si se pulsan.

### 5. Convenciones para que Claude alimente el scriptorium

Sin esto el scriptorium queda vacío. Abre
`/tmp/drop-pod-scriptorium/claudeconfig/.claude/CLAUDE.md` y copia la sección
**«Output en HTML»** completa (tokens de estilo, tipografías, `@media print`,
ubicación en `~/src/html/<repo-name>/`, rotación a `archive/`, compatibilidad
con iframe) al `~/.claude/CLAUDE.md` del usuario:

- Si el usuario no tiene `~/.claude/CLAUDE.md`, créalo con esa sección.
- Si ya lo tiene, añade la sección al final sin tocar lo suyo; si ya existe
  una sección de output HTML propia, muéstrale la diferencia y que decida.
- La sección es genérica (usa `$HOME` y el nombre del repo actual); no hay
  nada que adaptar.

### 6. Verificación final

1. `curl` al catálogo (paso 2) en verde.
2. Genera un HTML de prueba con las convenciones del paso 5 en
   `~/src/html/<repo-actual>/` y comprueba que aparece en el catálogo de
   `http://localhost:8080` y se abre en el panel lector.
3. Si se instaló el paso 3: `curl -s -o /dev/null -w '%{http_code}' http://scriptorium/` → 200.
4. Si se instaló el paso 4: los dos `curl` del bridge en verde.
5. Borra el clon temporal: `rm -rf /tmp/drop-pod-scriptorium`.

### Actualizaciones

Para actualizar a versiones nuevas del visor o del bridge, repite esta guía:
todos los pasos son idempotentes y las copias machacan las versiones viejas.
