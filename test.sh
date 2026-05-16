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
  if [[ -L "$dst" && "$resolved" == "$src" ]]; then
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
for bin in git zsh tmux fzf rg jq stow node npm curl wget gh zoxide htop tree; do
  check "$bin" command -v "$bin"
done
check "bat (bat o batcat)"  bash -c 'command -v bat &>/dev/null || command -v batcat &>/dev/null'
check "fd  (fd o fdfind)"   bash -c 'command -v fd  &>/dev/null || command -v fdfind  &>/dev/null'
if [[ "$PLATFORM" == "linux" ]]; then
  check "xclip" command -v xclip
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

# ── 5. Symlinks de dotfiles ───────────────────────────────────────────────────
section "Symlinks de dotfiles"
check_symlink "~/.gitconfig"                   "$HOME/.gitconfig"                    "$DOTFILES/git/.gitconfig"
check_symlink "~/.gitignore_global"            "$HOME/.gitignore_global"             "$DOTFILES/git/.gitignore_global"
check_symlink "~/.config/nvim"                 "$HOME/.config/nvim"                  "$DOTFILES/nvim"
check_symlink "~/.zshrc"                       "$HOME/.zshrc"                        "$DOTFILES/zsh/.zshrc"
check_symlink "~/.hushlogin"                   "$HOME/.hushlogin"                    "$DOTFILES/zsh/.hushlogin"
check_symlink "~/.config/zsh/claude-helpers.sh" "$HOME/.config/zsh/claude-helpers.sh" "$DOTFILES/zsh/.config/zsh/claude-helpers.sh"
check_symlink "~/.claude/settings.json"        "$HOME/.claude/settings.json"         "$DOTFILES/claudeconfig/.claude/settings.json"
check_symlink "~/.claude/hooks/notify-stop.sh" "$HOME/.claude/hooks/notify-stop.sh"  "$DOTFILES/claudeconfig/.claude/hooks/notify-stop.sh"
check_symlink "~/.claude/hooks/notify-attention.sh" "$HOME/.claude/hooks/notify-attention.sh" "$DOTFILES/claudeconfig/.claude/hooks/notify-attention.sh"
check_symlink "~/.claude/agents/architect.md"  "$HOME/.claude/agents/architect.md"   "$DOTFILES/claudeconfig/.claude/agents/architect.md"
check_symlink "~/.claude/agents/builder.md"    "$HOME/.claude/agents/builder.md"     "$DOTFILES/claudeconfig/.claude/agents/builder.md"
check_symlink "~/.claude/agents/reviewer.md"   "$HOME/.claude/agents/reviewer.md"    "$DOTFILES/claudeconfig/.claude/agents/reviewer.md"
check_symlink "~/.claude/agents/debugger.md"   "$HOME/.claude/agents/debugger.md"    "$DOTFILES/claudeconfig/.claude/agents/debugger.md"
check_symlink "~/.claude/agents/auditor.md"    "$HOME/.claude/agents/auditor.md"     "$DOTFILES/claudeconfig/.claude/agents/auditor.md"
check_symlink "~/.claude/commands/scaffold.md"     "$HOME/.claude/commands/scaffold.md"     "$DOTFILES/claudeconfig/.claude/commands/scaffold.md"
check_symlink "~/.claude/commands/feature.md"      "$HOME/.claude/commands/feature.md"      "$DOTFILES/claudeconfig/.claude/commands/feature.md"
check_symlink "~/.claude/commands/quick.md"        "$HOME/.claude/commands/quick.md"        "$DOTFILES/claudeconfig/.claude/commands/quick.md"
check_symlink "~/.claude/commands/milestone-run.md" "$HOME/.claude/commands/milestone-run.md" "$DOTFILES/claudeconfig/.claude/commands/milestone-run.md"
check_symlink "~/.claude/commands/debug.md"        "$HOME/.claude/commands/debug.md"        "$DOTFILES/claudeconfig/.claude/commands/debug.md"
check_symlink "~/.claude/commands/audit.md"        "$HOME/.claude/commands/audit.md"        "$DOTFILES/claudeconfig/.claude/commands/audit.md"
check_symlink "~/.claude/commands/research.md"     "$HOME/.claude/commands/research.md"     "$DOTFILES/claudeconfig/.claude/commands/research.md"

# ── 6. Permisos ───────────────────────────────────────────────────────────────
section "Permisos de ficheros"
check "~/.claude/hooks/notify-stop.sh ejecutable"      test -x "$HOME/.claude/hooks/notify-stop.sh"
check "~/.claude/hooks/notify-attention.sh ejecutable" test -x "$HOME/.claude/hooks/notify-attention.sh"

# ── 7. Configuración de git ───────────────────────────────────────────────────
section "Git config (~/.gitconfig)"
check "user.name = Fran"                  bash -c '[[ "$(git config --global user.name)" == "Fran" ]]'
check "user.email = jfcobarea@gmail.com"  bash -c '[[ "$(git config --global user.email)" == "jfcobarea@gmail.com" ]]'
check "core.pager = delta"                bash -c '[[ "$(git config --global core.pager)" == "delta" ]]'
check "init.defaultBranch = main"         bash -c '[[ "$(git config --global init.defaultBranch)" == "main" ]]'
check "pull.rebase = true"                bash -c '[[ "$(git config --global pull.rebase)" == "true" ]]'

# ── 8. Contenido de .zshrc ────────────────────────────────────────────────────
section "Contenido de ~/.zshrc"
check "carga oh-my-zsh"              grep -q 'source.*oh-my-zsh.sh'      "$HOME/.zshrc"
check "~/.local/bin en PATH"         grep -q '\.local/bin'               "$HOME/.zshrc"
check "init starship"                grep -q 'starship init'              "$HOME/.zshrc"
check "init zoxide"                  grep -q 'zoxide init'               "$HOME/.zshrc"
check "NTFY_TOPIC definido"          grep -q 'NTFY_TOPIC'                "$HOME/.zshrc"
check "sourcea claude-helpers.sh"    grep -q 'claude-helpers.sh'         "$HOME/.zshrc"
check "función serve definida"       grep -q '^serve()'                  "$HOME/.zshrc"
check "~/.tolkien_quotes existe"     test -f "$HOME/.tolkien_quotes"
check "~/.motd.sh existe"            test -f "$HOME/.motd.sh"

# ── 9. Claude Code — permisos en settings.json ────────────────────────────────
section "Claude Code settings"
claude_settings="$HOME/.claude/settings.json"
check "settings.json tiene Write(*)"   grep -q '"Write(\*)"'  "$claude_settings"
check "settings.json tiene Edit(*)"    grep -q '"Edit(\*)"'   "$claude_settings"
check "settings.json tiene Bash(*)"    grep -q '"Bash(\*)"'   "$claude_settings"
check "claude-new disponible en shell" bash -c 'source "$HOME/.config/zsh/claude-helpers.sh" 2>/dev/null && declare -f claude-new &>/dev/null'

# ── 10. Remote del repo de dotfiles ───────────────────────────────────────────
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
