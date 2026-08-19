# dotfiles

Configuración portable para arrancar una máquina nueva en minutos.

## Qué incluye

| Bloque | Descripción |
|---|---|
| **nvim/** | Neovim con lazy.nvim, LSP, Telescope, Treesitter, nvim-cmp |
| **git/** | `.gitconfig` con aliases, delta como pager, opciones de pull/push |
| **claudeconfig/** | `settings.json` de Claude Code + hook Stop + agentes y comandos multi-agente |
| **ssh/** | Alias de host en `~/.ssh/config.d/` (incluidos desde `~/.ssh/config`) |
| **starship/** | `starship.toml` con los timeouts del prompt subidos |
| **packages/** | `Brewfile` (macOS) y `apt-packages.txt` (Linux/Raspberry Pi) |
| **templates/** | Plantilla global `CLAUDE.md` para proyectos |

## Instalación en una máquina nueva

```bash
git clone https://github.com/TU_USUARIO/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

El script se encarga de todo:

1. **Detecta el SO** (`uname -s`): macOS o Linux/Debian/Raspbian
2. **Instala paquetes**
   - macOS: instala Homebrew si falta, luego `brew bundle`
   - Linux: `apt-get` + binarios de GitHub Releases para lo que no está en apt
     (neovim, git-delta, lazygit, eza, starship)
3. **Crea los symlinks**
   - `~/.gitconfig`, `~/.gitignore_global` vía GNU stow
   - `~/.config/nvim/` → symlink directo a `nvim/`
   - `~/.claude/settings.json` y `~/.claude/hooks/` vía stow
4. **Backup automático** — si un archivo de destino ya existe y no es un symlink al repo, lo mueve a `~/.dotfiles-backup/<timestamp>/` antes de reemplazarlo
5. **Idempotente** — ejecutarlo dos veces no rompe nada ni duplica symlinks

### Post-instalación

Añade estas líneas a tu `~/.zshrc` o `~/.bashrc`:

```bash
# Linux: symlinks de bat y fd creados por install.sh
export PATH="$HOME/.local/bin:$PATH"

# Starship prompt (si no está ya)
eval "$(starship init bash)"   # o zsh
```

### Secretos locales

Nada que sea secreto se versiona aquí. El `.zshrc` del repo sourcea
`~/.zshrc.local` si existe, y ese fichero nunca entra en el repo (`*.local` está
en `.gitignore`). Créalo a mano en cada máquina con permisos `600`:

```bash
umask 077 && cat > ~/.zshrc.local <<'EOF'
export NTFY_TOPIC=tu-topic-de-ntfy      # notificaciones de Claude Code
export DD_APP_KEY=tu-app-key-de-datadog
EOF
```

Los tokens de otras herramientas (`gh`, Docker, el OAuth de Claude Code) se
quedan en el store de cada herramienta — no los centralices aquí: tendrías que
duplicar el valor y quedaría exportado al entorno de todo proceso hijo.

Luego abre `nvim` — lazy.nvim instala los plugins en el primer arranque.

---

## Paquetes instalados

### Requeridos (en ambas plataformas)

`git` · `git-delta` · `lazygit` · `tmux` · `neovim` · `fzf` · `ripgrep` · `bat` · `eza` · `starship` · `jq` · `stow` · `node` · `gnu-coreutils` (macOS)

### Recomendados (marcados en los archivos de paquetes)

`fd` · `gh` (GitHub CLI) · `wget` · `zoxide` · `mise` · `htop` · `tldr` · `tree`

---

## Configuración de Git

Aliases disponibles:

| Alias | Comando real |
|---|---|
| `git st` | `status -sb` |
| `git co` | `checkout` |
| `git br` | `branch -v` |
| `git lg` | log gráfico con todas las ramas |
| `git last` | último commit con stats |
| `git undo` | deshace el último commit (conserva cambios) |

Delta muestra diffs en modo side-by-side con números de línea.

---

## Hook de notificación (Claude Code)

Cuando termina una sesión de Claude Code, `~/.claude/hooks/notify-stop.sh` envía una notificación a [ntfy.sh](https://ntfy.sh).

Requisito: tener `NTFY_TOPIC` exportado en el entorno.

Para silenciar el hook en jobs desatendidos, exporta `CLAUDE_NO_NOTIFY=1` antes de invocar `claude`: los hooks salen sin notificar y sin tocar `~/.claude/hooks/last-notify`.

---

## Limpieza diaria de worktrees (macOS)

`com.fran.worktree-cleanup` (03:15) barre los git worktrees y las ramas locales muertas de los repos configurados. El procedimiento vive en el skill `claudeconfig/.claude/skills/worktree-cleanup/SKILL.md`; `macos/worktree-cleanup.sh` es solo el wrapper que lo ejecuta headless (`claude -p /worktree-cleanup`).

- **Repos a barrer:** el array `REPOS` al principio del `SKILL.md`, en formato `ruta|rama-de-integración`. Para añadir un repo, una línea más.
- **Qué borra sin preguntar:** worktrees limpios cuya PR está `MERGED` en GitHub, y sus ramas. El merge se clasifica con `gh pr list`, no con `git branch --merged`: los repos con squash merge dan falsos negativos.
- **Qué no toca nunca:** el checkout principal, worktrees con cambios sin commitear, worktrees con procesos vivos dentro, ramas con PR cerrada sin mergear, ramas nunca pusheadas. Tampoco hace `push`, `commit`, `stash`, `clean` ni `reset`.
- **Red de seguridad:** antes de borrar vuelca `<sha> <repo> <rama>` a `~/.local/state/worktree-cleanup/deleted-branches-<fecha>.txt`. Para resucitar: `git branch <nombre> <sha>`.
- **Informe:** `~/.local/state/worktree-cleanup/report-<fecha>.md`. El informe se escribe siempre; su primera línea (`ESTADO: requiere-decision|informativo|silencioso`) decide si hay push a ntfy y con qué prioridad. Con `silencioso` no llega nada. Si el informe **falta**, el wrapper lo trata como fallo y avisa: sin informe no hay rastro de lo que hizo. Los logs se rotan a los 90 días.
- **Nada vive bajo `~/.claude/`:** el harness protege ese directorio y la escritura se deniega en una ejecución desatendida, sin error visible.
- **A mano:** `worktree-cleanup.sh --dry-run` clasifica e informa sin borrar nada. Log de ejecuciones en `run.log`, salida cruda en `last-run-output.txt`.

---

## Alias de SSH

`ssh/.ssh/config.d/ratatoskr.conf` define los alias para llegar a la Raspberry Pi sin escribir usuario ni dominio:

| Alias | Ruta | Cuándo |
|---|---|---|
| `ssh ratatoskr` | `ratatoskr.local` (mDNS) | En la red de casa |
| `ssh ratatoskr-ts` | `ratatoskr.tail69372f.ts.net` | Desde cualquier red, con tailscale levantado en los dos extremos |

`~/.ssh/config` **no** se symlinkea: puede contener hosts de trabajo o identidades de git que no viven aquí. `install.sh` solo le garantiza un `Include ~/.ssh/config.d/*.conf` en la primera línea, y son los ficheros de `config.d/` los que llegan por symlink desde el repo. Como ssh se queda con el primer valor de cada keyword, los alias del repo tienen prioridad sobre lo que haya debajo.

El paso de instalación fuerza `chmod 600` sobre los `.conf` del repo en cada ejecución: git no versiona más permiso que el bit de ejecución, así que un clon con `umask 002` los dejaría en 664 y ssh rechaza los ficheros de config escribibles por grupo.

Para que la conexión no pida contraseña, la clave pública de la máquina cliente tiene que estar en `~/.ssh/authorized_keys` de la Pi. Eso es por máquina y no se versiona: `ssh-copy-id ratatoskr`.

---

## starship

`starship/.config/starship.toml` sube dos timeouts del prompt y deja el resto en los valores de fábrica:

| Opción | Defecto | Aquí | Para qué |
|---|---|---|---|
| `scan_timeout` | 30 ms | 100 ms | Listar el directorio actual para decidir qué módulos de lenguaje mostrar |
| `command_timeout` | 500 ms | 2000 ms | Ejecutar comandos externos de versión (`node --version`, etc.) |

Sin esto, en la Raspberry Pi —raíz en tarjeta SD, node instalado vía nvm— el primer prompt tras abrir la shell salía con la caché de página vacía, se pasaba de los límites y starship escupía:

```
[WARN] - (starship::context): Scanning current directory timed out.
[WARN] - (starship::utils): Executing command ".../node" timed out.
```

En caliente las dos operaciones tardan ~10 ms, así que solo estorbaba el arranque en frío. Los warnings son inocuos —el prompt se pinta igual—, pero el módulo abortado puede dejarse fuera la versión del lenguaje.

---

## Plantilla CLAUDE.md

`templates/CLAUDE.md` es una plantilla comentada para colocar en `~/src/CLAUDE.md`. Claude Code la carga automáticamente para todos tus proyectos bajo `~/src/`. `install.sh` la copia si `~/src/` existe y no hay ya un `CLAUDE.md`.

---

## Estructura del repo

```
dotfiles/
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── nvim/
│   ├── init.lua
│   └── lua/
│       ├── config/        # options, keymaps, lazy bootstrap
│       └── plugins/       # un fichero por categoría
├── claudeconfig/
│   └── .claude/
│       ├── settings.json
│       ├── hooks/
│       │   └── notify-stop.sh
│       ├── agents/
│       │   ├── architect.md
│       │   ├── builder.md
│       │   ├── reviewer.md
│       │   ├── debugger.md
│       │   └── auditor.md
│       ├── commands/
│       │   ├── scaffold.md
│       │   ├── research.md
│       │   ├── specs.md
│       │   ├── feature.md
│       │   ├── quick.md
│       │   └── …
│       └── skills/
│           └── worktree-cleanup/
│               └── SKILL.md
├── ssh/
│   └── .ssh/
│       └── config.d/
│           └── ratatoskr.conf   # alias «ratatoskr» y «ratatoskr-ts»
├── starship/
│   └── .config/
│       └── starship.toml       # timeouts del prompt
├── macos/                      # LaunchAgents + scripts (scriptorium, jobs diarios)
├── templates/
│   └── CLAUDE.md
├── packages/
│   ├── Brewfile
│   └── apt-packages.txt
├── install.sh
└── README.md
```

## Claude Code multi-agent setup

Comandos disponibles globalmente en cualquier sesión de Claude Code:

| Comando | Cuándo usarlo |
|---|---|
| `/scaffold` | Proyecto nuevo desde cero (greenfield): crea SPEC.md, plan y cicla hitos |
| `/research` | El problema está abierto: explora opciones y trade-offs antes de decidir |
| `/specs` | Especificación detallada a base de preguntas, una a una. Puerta obligatoria antes de `/feature` |
| `/feature` | Implementa una feature ya especificada en un repo existente |
| `/milestone-run` | Avanza un ciclo de hito suelto (bajo nivel; normalmente se prefiere `/feature`) |
| `/quick` | Bugfix puntual, pregunta rápida o cambio pequeño sin crear estado |
| `/debug` | Bug conocido: reproducir, causa raíz, fix y verificación |
| `/audit` | Revisión proactiva del proyecto en busca de bugs |
| `/code-review-scriptorium` | Code review con el motor built-in y el informe completo en el scriptorium |
| `/walkthrough` | Recorrido diff a diff de un cambio o PR, en HTML, para el scriptorium |
| `/ask` | Dudas sobre el repo. Solo lectura |
| `/clickup` | Lee un issue de ClickUp por su URL y lo implementa |
| `/commit` | Trocea lo que hay sin commitear en commits atómicos |

La cadena para trabajo nuevo es **`/research` (opcional) → `/specs` → `/feature`**: primero se decide qué opción se toma, luego qué se construye exactamente, y solo entonces se implementa. `/feature` se niega a arrancar sin una spec en `APPROVED`.

Internamente los comandos delegan en cinco subagentes (`architect`, `builder`, `reviewer`, `debugger`, `auditor`) que se coordinan automáticamente.

### Instalación

Los archivos se instalan junto al resto de dotfiles con:

```bash
./install.sh
```

O si solo quieres instalar el bloque de Claude Code:

```bash
stow --dir=. --target="$HOME" --no-folding --restow claudeconfig
```

Los ficheros quedan en:

```
~/.claude/agents/architect.md
~/.claude/agents/builder.md
~/.claude/agents/reviewer.md
~/.claude/commands/scaffold.md
~/.claude/commands/research.md
~/.claude/commands/specs.md
~/.claude/commands/feature.md
~/.claude/commands/quick.md
~/.claude/commands/milestone-run.md
…
```

### Helper de shell: `claude-new`

Disponible tras instalar los dotfiles (sourced desde `.zshrc`):

```bash
claude-new <nombre-proyecto>
```

Crea `~/src/<nombre>`, inicializa un repo git y te deja listo para ejecutar `/scaffold` dentro de Claude Code.

---

## Atajos principales de Neovim

Leader es `Espacio`.

| Atajo | Acción |
|---|---|
| `<leader>ff` | Buscar fichero |
| `<leader>fg` | Buscar texto en proyecto |
| `<leader>fb` | Buscar buffer abierto |
| `-` | Explorador de ficheros (oil.nvim) |
| `gd` | Ir a definición (LSP) |
| `gr` | Ver referencias (LSP) |
| `K` | Documentación hover |
| `<leader>rn` | Renombrar símbolo |
| `<C-h/j/k/l>` | Moverse entre splits |

## Añadir un plugin de Neovim

Crea un fichero en `nvim/lua/plugins/`:

```lua
return {
  "autor/plugin",
  event = "VeryLazy",
  config = function()
    require("plugin").setup({})
  end,
}
```

lazy.nvim lo descubre automáticamente.
