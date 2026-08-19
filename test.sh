#!/usr/bin/env bash
# Verifica que la instalación de dotfiles esté completa. Ejecutar después de install.sh.
set -uo pipefail

CYN='\033[0;36m'; GRN='\033[0;32m'; YEL='\033[1;33m'; RED='\033[0;31m'
BOLD='\033[1m'; RST='\033[0m'

PASS=0; FAIL=0; SKIP=0
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
[[ "$OS" == "Darwin" ]] && PLATFORM="macos" || PLATFORM="linux"

section() { echo -e "\n${BOLD}${CYN}── $* ──${RST}"; }

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GRN}✓${RST} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${RST} $desc"
    FAIL=$((FAIL + 1))
  fi
}

check_symlink() {
  local desc="$1" dst="$2" src="$3"
  # readlink -f resolves relative symlinks (stow creates relative paths) to absolute
  local resolved; resolved="$(readlink -f "$dst" 2>/dev/null || true)"
  # No se exige que $dst sea symlink: stow pliega el árbol cuando el directorio
  # de destino no existe (~/.claude/skills → repo/…/skills), y entonces los
  # ficheros de dentro son reales, alcanzados a través del padre symlinkado.
  # Que readlink -f resuelva a $src ya prueba que la ruta pasa por el repo: un
  # fichero independiente resolvería a su propia ruta bajo $HOME.
  if [[ -e "$dst" && "$resolved" == "$src" ]]; then
    echo -e "  ${GRN}✓${RST} $desc"
    PASS=$((PASS + 1))
  else
    local raw; raw="$(readlink "$dst" 2>/dev/null || echo 'no es symlink')"
    echo -e "  ${RED}✗${RST} $desc  (resuelve a: ${resolved:-$raw})"
    FAIL=$((FAIL + 1))
  fi
}

skip() { echo -e "  ${YEL}~${RST} $1 ($2)"; SKIP=$((SKIP + 1)); }

# ── 1. Binarios básicos (apt / brew) ──────────────────────────────────────────
section "Binarios básicos"
for bin in git zsh tmux fzf rg jq stow node npm corepack curl wget unzip aws gh zoxide htop tree; do
  check "$bin" command -v "$bin"
done
check "bat (bat o batcat)"  bash -c 'command -v bat &>/dev/null || command -v batcat &>/dev/null'
check "fd  (fd o fdfind)"   bash -c 'command -v fd  &>/dev/null || command -v fdfind  &>/dev/null'
if [[ "$PLATFORM" == "linux" ]]; then
  check "xclip" command -v xclip
  check "tailscale" command -v tailscale
  check "tailscaled habilitado" systemctl is-enabled --quiet tailscaled
fi
if [[ "$PLATFORM" == "macos" ]]; then
  check "alerter" command -v alerter
fi

# ── 2. Binarios de GitHub Releases ────────────────────────────────────────────
section "Binarios de GitHub Releases"
for bin in nvim delta lazygit eza starship tldr; do
  check "$bin" command -v "$bin"
done

nvim_version_ok() {
  local min="0.11.0" ver
  ver=$(nvim --version 2>/dev/null | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [[ -n "$ver" ]] && printf '%s\n%s\n' "$min" "$ver" | sort -V | head -1 | grep -qx "$min"
}
check "nvim >= 0.11.0" nvim_version_ok

# ── 3. Wrappers ~/.local/bin (solo Linux) ─────────────────────────────────────
if [[ "$PLATFORM" == "linux" ]]; then
  section "Wrappers ~/.local/bin"
  if command -v batcat &>/dev/null; then
    check "~/.local/bin/bat → batcat" test -L "$HOME/.local/bin/bat"
  else
    skip "~/.local/bin/bat" "batcat no instalado"
  fi
  if command -v fdfind &>/dev/null; then
    check "~/.local/bin/fd → fdfind" test -L "$HOME/.local/bin/fd"
  else
    skip "~/.local/bin/fd" "fdfind no instalado"
  fi
fi

# ── 4. Oh My Zsh ──────────────────────────────────────────────────────────────
section "Oh My Zsh"
check "~/.oh-my-zsh existe"               test -d "$HOME/.oh-my-zsh"
check "plugin zsh-autosuggestions"        test -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
check "plugin zsh-syntax-highlighting"   test -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

default_shell_is_zsh() {
  if [[ "$PLATFORM" == "linux" ]]; then
    getent passwd "$USER" | cut -d: -f7 | grep -q zsh
  else
    dscl . -read "/Users/$USER" UserShell 2>/dev/null | grep -q zsh
  fi
}
check "shell por defecto es zsh" default_shell_is_zsh

# ── 5. nvm ────────────────────────────────────────────────────────────────────
section "nvm"
check "~/.nvm existe" test -d "$HOME/.nvm"

# ── 6. Symlinks de dotfiles ──────────────────────────────────────────────────
section "Symlinks de dotfiles"
check_symlink "~/.gitconfig"                   "$HOME/.gitconfig"                    "$DOTFILES/git/.gitconfig"
check_symlink "~/.gitignore_global"            "$HOME/.gitignore_global"             "$DOTFILES/git/.gitignore_global"
check_symlink "~/.config/nvim"                 "$HOME/.config/nvim"                  "$DOTFILES/nvim"
check_symlink "~/.zshrc"                       "$HOME/.zshrc"                        "$DOTFILES/zsh/.zshrc"
check_symlink "~/.hushlogin"                   "$HOME/.hushlogin"                    "$DOTFILES/zsh/.hushlogin"
check_symlink "~/.config/zsh/claude-helpers.sh" "$HOME/.config/zsh/claude-helpers.sh" "$DOTFILES/zsh/.config/zsh/claude-helpers.sh"
check_symlink "~/.claude/settings.json"        "$HOME/.claude/settings.json"         "$DOTFILES/claudeconfig/.claude/settings.json"
check_symlink "~/.claude/CLAUDE.md"            "$HOME/.claude/CLAUDE.md"             "$DOTFILES/claudeconfig/.claude/CLAUDE.md"
check_symlink "~/.claude/statusline.sh"        "$HOME/.claude/statusline.sh"         "$DOTFILES/claudeconfig/.claude/statusline.sh"
check_symlink "~/.claude/hooks/notify-stop.sh" "$HOME/.claude/hooks/notify-stop.sh"  "$DOTFILES/claudeconfig/.claude/hooks/notify-stop.sh"
check_symlink "~/.claude/hooks/notify-attention.sh" "$HOME/.claude/hooks/notify-attention.sh" "$DOTFILES/claudeconfig/.claude/hooks/notify-attention.sh"
check_symlink "~/.claude/hooks/ghostty-focus.sh" "$HOME/.claude/hooks/ghostty-focus.sh" "$DOTFILES/claudeconfig/.claude/hooks/ghostty-focus.sh"
check_symlink "~/.claude/hooks/claude-focus-last.sh" "$HOME/.claude/hooks/claude-focus-last.sh" "$DOTFILES/claudeconfig/.claude/hooks/claude-focus-last.sh"
check_symlink "~/.claude/hooks/block-protected-push.sh" "$HOME/.claude/hooks/block-protected-push.sh" "$DOTFILES/claudeconfig/.claude/hooks/block-protected-push.sh"
check_symlink "~/.claude/agents/architect.md"  "$HOME/.claude/agents/architect.md"   "$DOTFILES/claudeconfig/.claude/agents/architect.md"
check_symlink "~/.claude/agents/builder.md"    "$HOME/.claude/agents/builder.md"     "$DOTFILES/claudeconfig/.claude/agents/builder.md"
check_symlink "~/.claude/agents/reviewer.md"   "$HOME/.claude/agents/reviewer.md"    "$DOTFILES/claudeconfig/.claude/agents/reviewer.md"
check_symlink "~/.claude/agents/debugger.md"   "$HOME/.claude/agents/debugger.md"    "$DOTFILES/claudeconfig/.claude/agents/debugger.md"
check_symlink "~/.claude/agents/auditor.md"    "$HOME/.claude/agents/auditor.md"     "$DOTFILES/claudeconfig/.claude/agents/auditor.md"
check_symlink "~/.claude/commands/scaffold.md"     "$HOME/.claude/commands/scaffold.md"     "$DOTFILES/claudeconfig/.claude/commands/scaffold.md"
check_symlink "~/.claude/commands/specs.md"        "$HOME/.claude/commands/specs.md"        "$DOTFILES/claudeconfig/.claude/commands/specs.md"
check_symlink "~/.claude/commands/feature.md"      "$HOME/.claude/commands/feature.md"      "$DOTFILES/claudeconfig/.claude/commands/feature.md"
check_symlink "~/.claude/commands/quick.md"        "$HOME/.claude/commands/quick.md"        "$DOTFILES/claudeconfig/.claude/commands/quick.md"
check_symlink "~/.claude/commands/milestone-run.md" "$HOME/.claude/commands/milestone-run.md" "$DOTFILES/claudeconfig/.claude/commands/milestone-run.md"
check_symlink "~/.claude/commands/debug.md"        "$HOME/.claude/commands/debug.md"        "$DOTFILES/claudeconfig/.claude/commands/debug.md"
check_symlink "~/.claude/commands/audit.md"        "$HOME/.claude/commands/audit.md"        "$DOTFILES/claudeconfig/.claude/commands/audit.md"
check_symlink "~/.claude/commands/research.md"     "$HOME/.claude/commands/research.md"     "$DOTFILES/claudeconfig/.claude/commands/research.md"
check_symlink "~/.claude/commands/ask.md"          "$HOME/.claude/commands/ask.md"          "$DOTFILES/claudeconfig/.claude/commands/ask.md"
check_symlink "~/.claude/commands/commit.md"       "$HOME/.claude/commands/commit.md"       "$DOTFILES/claudeconfig/.claude/commands/commit.md"
check_symlink "~/.claude/commands/clickup.md"      "$HOME/.claude/commands/clickup.md"      "$DOTFILES/claudeconfig/.claude/commands/clickup.md"
check_symlink "~/.claude/commands/walkthrough.md"  "$HOME/.claude/commands/walkthrough.md"  "$DOTFILES/claudeconfig/.claude/commands/walkthrough.md"
check_symlink "~/.claude/commands/code-review-scriptorium.md" \
  "$HOME/.claude/commands/code-review-scriptorium.md" \
  "$DOTFILES/claudeconfig/.claude/commands/code-review-scriptorium.md"
check "/code-review built-in sin sombrear" \
  bash -c "[[ ! -e '$HOME/.claude/commands/code-review.md' && ! -L '$HOME/.claude/commands/code-review.md' ]]"
check_symlink "~/.claude/skills/worktree-cleanup/SKILL.md" \
  "$HOME/.claude/skills/worktree-cleanup/SKILL.md" \
  "$DOTFILES/claudeconfig/.claude/skills/worktree-cleanup/SKILL.md"

# ── 6b. Cadena de comandos de feature ────────────────────────────────────────
section "Cadena de comandos de feature"
specs_cmd="$DOTFILES/claudeconfig/.claude/commands/specs.md"
feature_cmd="$DOTFILES/claudeconfig/.claude/commands/feature.md"
research_cmd="$DOTFILES/claudeconfig/.claude/commands/research.md"
check "/specs escribe la fuente de verdad en plan/specs/" \
  grep -q 'plan/specs/<slug>.md' "$specs_cmd"
check "/specs pregunta de una en una" \
  grep -q 'Una pregunta por turno' "$specs_cmd"
check "/specs no se aprueba a sí misma" \
  grep -q 'nunca te apruebes tu propia spec' "$specs_cmd"
check "/specs renderiza al scriptorium" \
  grep -q 'src/html/<repo-name>/spec-<slug>.html' "$specs_cmd"
check "/feature exige spec APPROVED" \
  grep -q 'status: APPROVED' "$feature_cmd"
check "/feature no inventa el alcance" \
  grep -q 'para y dime que hay que pasar por `/specs`' "$feature_cmd"
check "/feature deriva hitos de los criterios de la spec" \
  grep -q 'derivados de los criterios de aceptación de la spec' "$feature_cmd"
check "/research hace hand-off a /specs" \
  grep -q 'Hand-off a /specs' "$research_cmd"
check "/research ya no salta a /feature" \
  bash -c "! grep -q 'READY_FOR_FEATURE' '$research_cmd'"

# ── 7. Permisos ───────────────────────────────────────────────────────────────
section "Permisos de ficheros"
check "~/.claude/hooks/notify-stop.sh ejecutable"      test -x "$HOME/.claude/hooks/notify-stop.sh"
check "~/.claude/hooks/notify-attention.sh ejecutable" test -x "$HOME/.claude/hooks/notify-attention.sh"
check "~/.claude/hooks/ghostty-focus.sh ejecutable"    test -x "$HOME/.claude/hooks/ghostty-focus.sh"
check "~/.claude/hooks/claude-focus-last.sh ejecutable" test -x "$HOME/.claude/hooks/claude-focus-last.sh"
check "~/.claude/hooks/block-protected-push.sh ejecutable" test -x "$HOME/.claude/hooks/block-protected-push.sh"
check "notify-stop usa alerter"      grep -q 'alerter' "$HOME/.claude/hooks/notify-stop.sh"
check "notify-attention usa alerter" grep -q 'alerter' "$HOME/.claude/hooks/notify-attention.sh"
check "notify-stop escribe last-notify"      grep -q 'last-notify' "$HOME/.claude/hooks/notify-stop.sh"
check "notify-attention escribe last-notify" grep -q 'last-notify' "$HOME/.claude/hooks/notify-attention.sh"
check "claude-focus-last cierra el banner"   grep -q 'pkill -x alerter' "$HOME/.claude/hooks/claude-focus-last.sh"
check "claude-focus-last barre banners huérfanos" grep -q 'AXNotificationCenterAlert' "$HOME/.claude/hooks/claude-focus-last.sh"
check "notify-stop honra CLAUDE_NO_NOTIFY"      grep -q 'CLAUDE_NO_NOTIFY' "$HOME/.claude/hooks/notify-stop.sh"
check "notify-attention honra CLAUDE_NO_NOTIFY" grep -q 'CLAUDE_NO_NOTIFY' "$HOME/.claude/hooks/notify-attention.sh"

# ── 7b. macOS: LaunchAgent archive-downloads ──────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — archive-downloads"
  check_symlink "~/.local/bin/archive-downloads.sh" \
    "$HOME/.local/bin/archive-downloads.sh" "$DOTFILES/macos/archive-downloads.sh"
  check_symlink "~/Library/LaunchAgents/com.fran.archive-downloads.plist" \
    "$HOME/Library/LaunchAgents/com.fran.archive-downloads.plist" \
    "$DOTFILES/macos/com.fran.archive-downloads.plist"
  check "archive-downloads.sh ejecutable" test -x "$DOTFILES/macos/archive-downloads.sh"
  check "script excluye el README de política" \
    grep -q "Downloads Policy.txt" "$DOTFILES/macos/archive-downloads.sh"
  check "LaunchAgent cargado" bash -c 'launchctl list | grep -q com.fran.archive-downloads'
fi

# ── 7b-bis. macOS: LaunchAgent worktree-cleanup ───────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — worktree-cleanup"
  skill="$DOTFILES/claudeconfig/.claude/skills/worktree-cleanup/SKILL.md"
  wrapper="$DOTFILES/macos/worktree-cleanup.sh"

  check_symlink "~/.local/bin/worktree-cleanup.sh" \
    "$HOME/.local/bin/worktree-cleanup.sh" "$wrapper"
  check_symlink "~/Library/LaunchAgents/com.fran.worktree-cleanup.plist" \
    "$HOME/Library/LaunchAgents/com.fran.worktree-cleanup.plist" \
    "$DOTFILES/macos/com.fran.worktree-cleanup.plist"
  check "worktree-cleanup.sh ejecutable" test -x "$wrapper"
  check "LaunchAgent worktree-cleanup cargado" \
    bash -c 'launchctl list | grep -q com.fran.worktree-cleanup'
  check "directorio de estado existe" test -d "$HOME/.local/state/worktree-cleanup"

  check "wrapper silencia los hooks de notificación" grep -q 'CLAUDE_NO_NOTIFY' "$wrapper"
  check "wrapper rota los logs a 90 días"            grep -q 'RETENTION_DAYS=90' "$wrapper"
  check "wrapper serializa con lock"                 grep -q 'LOCK_DIR' "$wrapper"
  check "wrapper espera a que haya red"              grep -q 'api.github.com' "$wrapper"
  check "wrapper resuelve NTFY_TOPIC"                grep -q 'resolve_ntfy_topic' "$wrapper"
  check "wrapper calla solo con ESTADO silencioso"   grep -q 'silencioso\*' "$wrapper"
  check "wrapper avisa si falta el informe"          grep -q 'sin escribir el informe' "$wrapper"
  check "wrapper no escribe en ~/.claude"     bash -c '! grep -q "claude/logs" "'"$wrapper"'"'
  check "wrapper tolera bash 3.2 sin timeout"        grep -q 'runner=(env)' "$wrapper"
  wrapper_runs_on_bash32() { /bin/bash -n "$wrapper"; }
  check "wrapper parsea con /bin/bash 3.2" wrapper_runs_on_bash32
  check "wrapper busca el topic en ~/.zshrc.local" grep -q 'zshrc.local' "$wrapper"
  ntfy_topic_resuelve() {
    local fn t
    fn="$(sed -n '/^resolve_ntfy_topic()/,/^}/p' "$wrapper")"
    [[ -n "$fn" ]] || return 1
    t="$(unset NTFY_TOPIC; eval "$fn"; resolve_ntfy_topic)"
    [[ -n "$t" ]]
  }
  check "resolve_ntfy_topic devuelve un topic" ntfy_topic_resuelve

  check "skill clasifica el merge con gh pr list"    grep -q 'gh pr list' "$skill"
  check "skill hace fetch --prune antes de decidir"  grep -q 'fetch --prune origin' "$skill"
  check "skill vuelca la red de seguridad"           grep -q 'deleted-branches-' "$skill"
  check "skill protege el checkout principal"        grep -q 'Nunca borres el checkout principal' "$skill"
  check "skill prohíbe git stash"                    grep -q 'Nunca uses .git stash' "$skill"
  check "skill deja intactos los worktrees sucios"   grep -q 'lo toques automáticamente' "$skill"
  check "skill no emite veredictos de borrabilidad"  grep -q 'No emitas veredictos de borrabilidad' "$skill"
  check "skill emite la cabecera ESTADO"             grep -q 'ESTADO: requiere-decision' "$skill"
  check "skill contempla el estado silencioso"       grep -q 'ESTADO: silencioso' "$skill"
  check "skill escribe siempre el informe"           grep -q 'Escribe siempre el informe' "$skill"
  check "skill escribe fuera de ~/.claude"    bash -c '! grep -q "claude/logs" "'"$skill"'"'
  check "skill lista los repos configurables"        grep -q 'src/revel/revel-app|development' "$skill"
fi

# ── 7c. macOS: servidor web scriptorium ─────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — scriptorium"
  check "caddy instalado" command -v caddy
  check_symlink "~/.config/caddy/scriptorium.Caddyfile" \
    "$HOME/.config/caddy/scriptorium.Caddyfile" "$DOTFILES/macos/scriptorium.Caddyfile"
  check_symlink "~/.config/caddy/scriptorium-browse.html" \
    "$HOME/.config/caddy/scriptorium-browse.html" "$DOTFILES/macos/scriptorium-browse.html"
  check_symlink "~/.local/bin/scriptorium-serve.sh" \
    "$HOME/.local/bin/scriptorium-serve.sh" "$DOTFILES/macos/scriptorium-serve.sh"
  check_symlink "~/Library/LaunchAgents/com.fran.scriptorium.plist" \
    "$HOME/Library/LaunchAgents/com.fran.scriptorium.plist" \
    "$DOTFILES/macos/com.fran.scriptorium.plist"
  check "plantilla browse tiene export a PDF" grep -q 'function exportPdf' "$DOTFILES/macos/scriptorium-browse.html"
  check "plantilla browse tiene tiempo de lectura" grep -q 'function readingTime' "$DOTFILES/macos/scriptorium-browse.html"
  check "plantilla browse arranca con el catálogo colapsado" grep -q '<body class="nav-collapsed">' "$DOTFILES/macos/scriptorium-browse.html"
  check "scriptorium-serve.sh ejecutable" test -x "$DOTFILES/macos/scriptorium-serve.sh"
  check "scriptorium-root-setup.sh ejecutable" test -x "$DOTFILES/macos/scriptorium-root-setup.sh"
  check "LaunchAgent scriptorium cargado" bash -c 'launchctl list | grep -q com.fran.scriptorium'
  # Acceso por http://scriptorium (puerto 80): install.sh lo habilita con sudo.
  check "scriptorium resuelve en /etc/hosts" \
    bash -c 'grep -qE "^[^#]*[[:space:]]scriptorium([[:space:]]|$)" /etc/hosts'
  check "ancla pf scriptorium instalada" test -f /etc/pf.anchors/scriptorium
  check "ruleset pf scriptorium instalado" test -f /etc/pf-scriptorium.conf
  check "LaunchDaemon pf scriptorium instalado" \
    test -f /Library/LaunchDaemons/com.fran.scriptorium-pf.plist
fi

# ── 7d. macOS: bridge del botón «Compartir» del scriptorium ─────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — scriptorium-share"
  check_symlink "~/.local/bin/scriptorium-share.py" \
    "$HOME/.local/bin/scriptorium-share.py" "$DOTFILES/macos/scriptorium-share.py"
  check_symlink "~/.local/bin/scriptorium-share-serve.sh" \
    "$HOME/.local/bin/scriptorium-share-serve.sh" "$DOTFILES/macos/scriptorium-share-serve.sh"
  check_symlink "~/Library/LaunchAgents/com.fran.scriptorium-share.plist" \
    "$HOME/Library/LaunchAgents/com.fran.scriptorium-share.plist" \
    "$DOTFILES/macos/com.fran.scriptorium-share.plist"
  check "scriptorium-share-serve.sh ejecutable" test -x "$DOTFILES/macos/scriptorium-share-serve.sh"
  check "LaunchAgent scriptorium-share cargado" bash -c 'launchctl list | grep -q com.fran.scriptorium-share'
  check "bridge responde en 127.0.0.1:8737/shares" \
    bash -c 'curl -fsS --max-time 3 http://127.0.0.1:8737/shares'
  check "proxy same-origin /-/shares responde vía Caddy" \
    bash -c 'curl -fsS --max-time 3 http://localhost:8080/-/shares'
  check "Caddyfile expone la ruta /-/*" grep -q 'handle_path /-/\*' "$DOTFILES/macos/scriptorium.Caddyfile"
  check "Caddyfile oculta el mapping del listado" \
    grep -q 'hide .scriptorium-shares.json' "$DOTFILES/macos/scriptorium.Caddyfile"
fi

# ── 7e. macOS: config de Ghostty ──────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — Ghostty"
  check "Ghostty instalado" test -d "/Applications/Ghostty.app"
  check_symlink "~/.config/ghostty/config.ghostty" \
    "$HOME/.config/ghostty/config.ghostty" "$DOTFILES/ghostty/.config/ghostty/config.ghostty"
  check "window-save-state = always" \
    grep -q '^window-save-state = always' "$HOME/.config/ghostty/config.ghostty"
fi

# ── 7f. macOS: triple Shift → foco a Ghostty (Hammerspoon) ───────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — Hammerspoon (foco Ghostty por teclado)"
  check "Hammerspoon instalado" test -d "/Applications/Hammerspoon.app"
  check_symlink "~/.hammerspoon/init.lua" \
    "$HOME/.hammerspoon/init.lua" "$DOTFILES/hammerspoon/.hammerspoon/init.lua"
  check "init.lua invoca claude-focus-last.sh" \
    grep -q 'claude-focus-last.sh' "$HOME/.hammerspoon/init.lua"
  check "Hammerspoon en ejecución" pgrep -xq Hammerspoon
fi

# ── 7g. macOS: Tailscale ──────────────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — Tailscale"
  if [[ -d "/Applications/Tailscale.app" ]]; then
    check "shields-up activo" \
      bash -c '"/Applications/Tailscale.app/Contents/MacOS/Tailscale" debug prefs | jq -e ".ShieldsUp == true"'
  else
    skip "Tailscale" "no instalado en este Mac"
  fi
fi

# ── 7h. macOS: VLC ────────────────────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  section "macOS — VLC"
  check "VLC instalado" test -d "/Applications/VLC.app"
fi

# ── 7i. SSH: alias de host ────────────────────────────────────────────────────
section "SSH (~/.ssh/config.d/)"
ssh_conf="$DOTFILES/ssh/.ssh/config.d/ratatoskr.conf"
check_symlink "~/.ssh/config.d/ratatoskr.conf" \
  "$HOME/.ssh/config.d/ratatoskr.conf" "$ssh_conf"
check "~/.ssh/config incluye config.d/" \
  grep -qF 'Include ~/.ssh/config.d/*.conf' "$HOME/.ssh/config"
check "el Include va en la primera línea" \
  bash -c '[[ "$(head -1 "$HOME/.ssh/config")" == "Include ~/.ssh/config.d/*.conf" ]]'
check "~/.ssh/config no es escribible por grupo/otros" \
  bash -c '[[ -z "$(find "$HOME/.ssh/config" -perm /go+w)" ]]'
check "ratatoskr.conf no es escribible por grupo/otros" \
  bash -c '[[ -z "$(find "'"$ssh_conf"'" -perm /go+w)" ]]'
check "alias ratatoskr resuelve a ratatoskr.local" \
  bash -c '[[ "$(ssh -G ratatoskr | awk "/^hostname /{print \$2}")" == "ratatoskr.local" ]]'
check "alias ratatoskr-ts resuelve al nombre MagicDNS" \
  bash -c '[[ "$(ssh -G ratatoskr-ts | awk "/^hostname /{print \$2}")" == "ratatoskr.tail69372f.ts.net" ]]'
check "los dos alias usan el usuario fran" \
  bash -c '[[ "$(ssh -G ratatoskr | awk "/^user /{print \$2}")" == "fran" && "$(ssh -G ratatoskr-ts | awk "/^user /{print \$2}")" == "fran" ]]'

# ── 8. Configuración de git ───────────────────────────────────────────────────
section "Git config (~/.gitconfig)"
check "user.name = Fran"                  bash -c '[[ "$(git config --global user.name)" == "Fran" ]]'
check "user.email = jfcobarea@gmail.com"  bash -c '[[ "$(git config --global user.email)" == "jfcobarea@gmail.com" ]]'
check "core.pager = delta"                bash -c '[[ "$(git config --global core.pager)" == "delta" ]]'
check "init.defaultBranch = main"         bash -c '[[ "$(git config --global init.defaultBranch)" == "main" ]]'
check "pull.rebase = false"               bash -c '[[ "$(git config --global pull.rebase)" == "false" ]]'
check "credential helper github.com = gh"  bash -c 'git config --global --get-all "credential.https://github.com.helper" | grep -q "gh auth git-credential"'
check "credential helper gist = gh"        bash -c 'git config --global --get-all "credential.https://gist.github.com.helper" | grep -q "gh auth git-credential"'

# ── 9. Contenido de .zshrc ────────────────────────────────────────────────────
section "Contenido de ~/.zshrc"
check "carga oh-my-zsh"              grep -q 'source.*oh-my-zsh.sh'      "$HOME/.zshrc"
check "~/.local/bin en PATH"         grep -q '\.local/bin'               "$HOME/.zshrc"
check "init starship"                grep -q 'starship init'              "$HOME/.zshrc"
check "init zoxide"                  grep -q 'zoxide init'               "$HOME/.zshrc"
check "sourcea claude-helpers.sh"    grep -q 'claude-helpers.sh'         "$HOME/.zshrc"
check "función serve definida"       grep -q '^serve()'                  "$HOME/.zshrc"
check "JAVA_HOME (Android Studio JBR)" grep -q 'JAVA_HOME'               "$HOME/.zshrc"
check "ANDROID_HOME en PATH"         grep -q 'ANDROID_HOME'              "$HOME/.zshrc"
check "~/.tolkien_quotes existe"     test -f "$HOME/.tolkien_quotes"
check "~/.motd.sh existe"            test -f "$HOME/.motd.sh"
check "sourcea ~/.zshrc.local"       grep -q 'zshrc.local'               "$HOME/.zshrc"

# ── 9b. Secretos locales (nunca versionados) ──────────────────────────────────
section "Secretos locales (~/.zshrc.local)"
zshrc_local_no_versionado() {
  ! git -C "$DOTFILES" ls-files --error-unmatch \
    zsh/.zshrc.local .zshrc.local &>/dev/null
}
zshrc_local_ignorado() {
  git -C "$DOTFILES" check-ignore -q .zshrc.local
}
ntfy_topic_no_versionado() {
  ! grep -rqE '^[[:space:]]*export[[:space:]]+NTFY_TOPIC=' "$DOTFILES/zsh/.zshrc"
}
check "~/.zshrc.local no está en el repo" zshrc_local_no_versionado
check "*.local ignorado por git"          zshrc_local_ignorado
check "NTFY_TOPIC no está en el .zshrc versionado" ntfy_topic_no_versionado
if [[ -f "$HOME/.zshrc.local" ]]; then
  zshrc_local_perms_600() {
    [[ "$(stat -f '%Lp' "$HOME/.zshrc.local" 2>/dev/null \
       || stat -c '%a' "$HOME/.zshrc.local")" == "600" ]]
  }
  check "~/.zshrc.local con permisos 600" zshrc_local_perms_600
  check "~/.zshrc.local no es un symlink al repo" test ! -L "$HOME/.zshrc.local"
  check "NTFY_TOPIC definido en ~/.zshrc.local" \
    grep -qE '^[[:space:]]*export[[:space:]]+NTFY_TOPIC=' "$HOME/.zshrc.local"
else
  skip "~/.zshrc.local" "no existe en esta máquina"
fi

# ── 10. Claude Code — permisos en settings.json ───────────────────────────────
section "Claude Code settings"
claude_settings="$HOME/.claude/settings.json"
check "settings.json tiene Write(*)"   grep -q '"Write(\*)"'  "$claude_settings"
check "settings.json tiene Edit(*)"    grep -q '"Edit(\*)"'   "$claude_settings"
check "settings.json tiene Bash(*)"    grep -q '"Bash(\*)"'   "$claude_settings"
check "plugin codex habilitado"        jq -e '.enabledPlugins["codex@openai-codex"] == true' "$claude_settings"
check "marketplace openai-codex registrado" jq -e '.extraKnownMarketplaces["openai-codex"].source.repo == "openai/codex-plugin-cc"' "$claude_settings"
check "claude-new disponible en shell" bash -c 'source "$HOME/.config/zsh/claude-helpers.sh" 2>/dev/null && declare -f claude-new &>/dev/null'
check "función claude (cuenta personal)" bash -c 'source "$HOME/.config/zsh/claude-helpers.sh" 2>/dev/null && declare -f claude &>/dev/null'
check "deny de git push --all"          jq -e '.permissions.deny | index("Bash(git push --all *)")' "$claude_settings"
check "deny de git push --mirror"       jq -e '.permissions.deny | index("Bash(git push --mirror *)")' "$claude_settings"
check "sin deny total de git push"      bash -c "! jq -e '.permissions.deny | index(\"Bash(git push:*)\")' '$claude_settings' >/dev/null"
check "deny de rutas sensibles con Edit(...)" \
  jq -e '.permissions.deny | index("Edit(/etc/*)") and index("Edit(/usr/*)") and index("Edit(/boot/*)") and index("Edit(~/.ssh/*)")' "$claude_settings"
check "sin deny con Write(...) (no se evalúan)" \
  bash -c "! jq -e '.permissions.deny | map(select(startswith(\"Write(\"))) | length > 0' '$claude_settings' >/dev/null"
check "hook PreToolUse llama a block-protected-push" \
  jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.type=="command") | .command | test("block-protected-push.sh")' "$claude_settings"

push_hook="$HOME/.claude/hooks/block-protected-push.sh"
push_hook_verdict() {
  local branch="$1" cmd="$2" expected="$3" repo verdict
  repo="$(mktemp -d)"
  git -C "$repo" init -q -b "$branch" >/dev/null 2>&1
  git -C "$repo" -c commit.gpgsign=false commit -q --allow-empty -m init >/dev/null 2>&1
  local output
  output="$(printf '{"cwd":"%s","tool_input":{"command":%s}}' "$repo" "$(jq -Rn --arg c "$cmd" '$c')" \
    | "$push_hook")"
  rm -rf "$repo"
  if [[ -z "$output" ]]; then
    verdict="allow"
  else
    verdict="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')"
  fi
  [[ "$verdict" == "$expected" ]]
}
check "hook bloquea push estando en main"      push_hook_verdict main      'git push' deny
check "hook bloquea push explícito a main"     push_hook_verdict feature/x 'git push origin main' deny
check "hook bloquea HEAD:MASTER"               push_hook_verdict feature/x 'git push origin HEAD:MASTER' deny
check "hook bloquea refs/heads/alpha"          push_hook_verdict feature/x 'git push origin refs/heads/alpha' deny
check "hook bloquea --delete de rama protegida" push_hook_verdict feature/x 'git push origin --delete development' deny
check "hook bloquea push --all"                push_hook_verdict feature/x 'git push --all origin' deny
check "hook bloquea rama indeterminable"       push_hook_verdict feature/x 'git push origin "$RAMA"' deny
check "hook bloquea push en cadena a dev"      push_hook_verdict feature/x 'git commit -m x && git push origin dev' deny
check "hook permite push en rama de trabajo"   push_hook_verdict feature/x 'git push' allow
check "hook permite push explícito a rama de trabajo" push_hook_verdict main 'git push -u origin feature/x' allow
check "hook permite --force-with-lease en rama de trabajo" \
  push_hook_verdict feature/x 'git push --force-with-lease origin feature/x' allow
check "hook ignora comandos que no son push"   push_hook_verdict main 'git status' allow
check "statusLine configurado"         jq -e '.statusLine.type == "command"' "$claude_settings"
check "statusLine apunta a statusline.sh" \
  bash -c "jq -r '.statusLine.command' '$claude_settings' | grep -q 'statusline.sh'"
check "statusline.sh es ejecutable"    test -x "$DOTFILES/claudeconfig/.claude/statusline.sh"
check "statusline.sh usa --no-optional-locks en git" \
  grep -q -- '--no-optional-locks' "$DOTFILES/claudeconfig/.claude/statusline.sh"
check "statusline.sh muestra contexto" \
  grep -q 'context_window' "$DOTFILES/claudeconfig/.claude/statusline.sh"
check "statusline.sh muestra rate limits" \
  grep -q 'rate_limits' "$DOTFILES/claudeconfig/.claude/statusline.sh"
check "statusline.sh usa resets_at para el tiempo transcurrido" \
  grep -q 'resets_at' "$DOTFILES/claudeconfig/.claude/statusline.sh"
check "statusline.sh rinde cupo y tiempo de ventana" \
  bash -c "echo '{\"cwd\":\"\$HOME\",\"model\":{\"display_name\":\"test\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":19,\"resets_at\":'\$(( \$(date +%s) + 3600 ))'},\"seven_day\":{\"used_percentage\":41,\"resets_at\":'\$(( \$(date +%s) + 86400 ))'}}}' | sh '$DOTFILES/claudeconfig/.claude/statusline.sh' | grep -q '◔19%.*◷80%.*◑41%.*◷85%'"
check "statusline.sh renderiza sin errores" \
  bash -c "echo '{\"cwd\":\"\$HOME\",\"model\":{\"display_name\":\"test\"},\"context_window\":{\"used_percentage\":5,\"total_input_tokens\":50000,\"context_window_size\":1000000},\"rate_limits\":{\"five_hour\":{\"used_percentage\":10},\"seven_day\":{\"used_percentage\":20}}}' | sh '$DOTFILES/claudeconfig/.claude/statusline.sh' | grep -q 'ctx 5%'"

# ── 11. Remote del repo de dotfiles ───────────────────────────────────────────
section "Remote de dotfiles"
dotfiles_remote_is_ssh() {
  local url
  url="$(git -C "$DOTFILES" remote get-url origin 2>/dev/null)"
  [[ "$url" == git@github.com:* ]]
}
check "remote usa SSH (git@github.com)" dotfiles_remote_is_ssh

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Resultado ────────────────────────────────────────────${RST}"
echo -e "  ${GRN}✓ $PASS pasados${RST}   ${RED}✗ $FAIL fallidos${RST}   ${YEL}~ $SKIP omitidos${RST}"
echo ""
if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${RED}Hay tests fallidos. Vuelve a ejecutar ./install.sh para intentar corregirlos.${RST}"
  exit 1
fi
echo -e "  ${GRN}Todos los checks pasaron.${RST}"
