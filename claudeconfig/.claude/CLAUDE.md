# Preferencias personales — Fran

Este fichero contiene preferencias globales del usuario. Se carga **en toda sesión de Claude Code, en cualquier repositorio**.

## Tono

- Tono neutro, profesional y directo. Sin persona ni roleplay.
- Nada de metáforas temáticas, apelativos ni personajes. La voz no adorna: va al contenido técnico.
- Refiérete a los subagentes por su slug técnico (`architect`, `builder`, `reviewer`, `debugger`, `auditor`).

## Output en HTML

Cuando generes HTML como **output principal** para el usuario (artefactos de `/research`, reviews HTML, audits HTML, mockups, dashboards, prototipos):

- **Dark mode hard-coded.** Paleta dark fija en `:root` desde el principio.
- **No** uses `@media (prefers-color-scheme: dark)` — eso depende del SO; el usuario quiere dark siempre.
- **No** ofrezcas light mode como fallback ni añadas toggle.
- Paleta recomendada: fondos muy oscuros (`#09090b`/`#18181b`), texto claro, acentos semánticos saturados (verde aprobado, rojo crítico, amarillo warning, azul info) para mantener contraste sobre fondo oscuro.
- HTML autocontenido: CSS inline, sin dependencias externas, abre con `file://` sin red.
- **Ubicación.** Si el HTML se genera desde un repositorio, créalo en `~/src/html/<repo-name>/`, donde `<repo-name>` es el nombre del directorio raíz del repo (el basename de `git rev-parse --show-toplevel`). Ejemplo: desde un repo `revel-app` → `~/src/html/revel-app/`. Crea el directorio si no existe. No dejes el HTML dentro del propio repo salvo que el usuario lo pida explícitamente.
- **Compatible con el bibliotecario.** Todo HTML que generes en `~/src/html/` lo sirve y cataloga el servidor local "bibliotecario" (Caddy), que lista el árbol y **previsualiza los `.html` dentro de un iframe** en su panel lector. Para que encaje:
  - Extensión `.html` y nombre de fichero descriptivo en kebab-case (el catálogo filtra por extensión y abre inline solo los `.html`).
  - Debe verse bien **embebido en un iframe estrecho**: layout responsive, nada de frame-busting ni `target="_top"`, sin asumir que es la ventana top-level (no dependas de `window.top`, popups, ni de la URL de la barra).
  - El dark-mode fijo y el ser autocontenido (reglas de arriba) ya lo hacen consistente con el visor; mantenlos.

## Commits y trabajo

- **No hagas commits salvo que el usuario lo pida explícitamente** (con `/commit` o pidiéndolo con palabras). Por defecto, implementa los cambios y déjalos en el working tree sin commitear; el usuario decide cuándo y qué se commitea.
- En todo repositorio, sigue las reglas de commits atómicos si están descritas en el `CLAUDE.md` del proyecto.
- No saltes hooks (`--no-verify`, `--no-gpg-sign`) salvo petición explícita.
- Prefiere crear commits nuevos antes que `--amend` cuando algo falla.
- **Nunca hagas `git push` en ningún repositorio.** Todo push es manual y lo hace el usuario. Hay un hook que lo bloquea; no intentes sortearlo.

## Cómo se actualiza este fichero

- Vive versionado en el repo de dotfiles del usuario: `claudeconfig/.claude/CLAUDE.md`.
- Está symlinkado a `~/.claude/CLAUDE.md` por stow.
- Para añadir preferencias durables nuevas, edita el fichero del dotfile y `git commit`. El test del proyecto verifica que el symlink existe.
