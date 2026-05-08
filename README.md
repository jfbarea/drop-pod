# dotfiles

Configuración portable para arrancar una máquina nueva en minutos.

## Qué incluye

| Bloque | Descripción |
|---|---|
| **nvim/** | Neovim con lazy.nvim, LSP, Telescope, Treesitter, nvim-cmp |
| **git/** | `.gitconfig` con aliases, delta como pager, opciones de pull/push |
| **claudeconfig/** | `settings.json` de Claude Code + hook Stop + agentes y comandos multi-agente |
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
# Claude Code — notificaciones al terminar sesión
export NTFY_TOPIC=tu-topic-de-ntfy

# Linux: symlinks de bat y fd creados por install.sh
export PATH="$HOME/.local/bin:$PATH"

# Starship prompt (si no está ya)
eval "$(starship init bash)"   # o zsh
```

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
│       │   └── reviewer.md
│       └── commands/
│           ├── scaffold.md
│           ├── feature.md
│           ├── quick.md
│           └── milestone-run.md
├── templates/
│   └── CLAUDE.md
├── packages/
│   ├── Brewfile
│   └── apt-packages.txt
├── install.sh
└── README.md
```

## Claude Code multi-agent setup

Tres comandos disponibles globalmente en cualquier sesión de Claude Code:

| Comando | Cuándo usarlo |
|---|---|
| `/scaffold` | Proyecto nuevo desde cero (greenfield): crea SPEC.md, plan y cicla hitos |
| `/feature` | Añadir una feature a un repo existente sin tocar el plan actual |
| `/quick` | Bugfix puntual, pregunta rápida o cambio pequeño sin crear estado |

Internamente los comandos delegan en tres subagentes (`architect`, `builder`, `reviewer`) que se coordinan automáticamente.

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
~/.claude/commands/feature.md
~/.claude/commands/quick.md
~/.claude/commands/milestone-run.md
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
