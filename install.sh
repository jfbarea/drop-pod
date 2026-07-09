#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
CYN='\033[0;36m'; GRN='\033[0;32m'; YEL='\033[1;33m'; RED='\033[0;31m'; RST='\033[0m'
step() { echo -e "${CYN}==> $*${RST}"; }
ok()   { echo -e "${GRN}    ✓ $*${RST}"; }
warn() { echo -e "${YEL}    ! $*${RST}"; }
err()  { echo -e "${RED}    ✗ $*${RST}" >&2; }

# ── Globals ───────────────────────────────────────────────────────────────────
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      err "Unsupported OS: $OS"; exit 1 ;;
esac

step "Dotfiles: $DOTFILES  |  Platform: $PLATFORM ($ARCH)"

# ─────────────────────────────────────────────────────────────────────────────
# Package installation
# ─────────────────────────────────────────────────────────────────────────────

install_packages_macos() {
  if ! command -v brew &>/dev/null; then
    step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script (Apple Silicon)
    [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    ok "Homebrew already installed"
  fi
  step "Running brew bundle..."
  brew bundle --file="$DOTFILES/packages/Brewfile"
  ok "Homebrew packages ready"

  install_macos_extras
}

# Paquetes solo-macOS no disponibles en Homebrew — bajados de GitHub Releases
install_macos_extras() {
  local ver url tmp

  # alerter — notificaciones nativas con detección de click (reemplaza a
  # terminal-notifier, cuyo bundle 2.0.0 ya no se registra en macOS reciente y
  # descarta los banners en silencio). No tiene fórmula en Homebrew-core.
  if ! command -v alerter &>/dev/null; then
    step "Installing alerter..."
    ver="$(curl -fsSL https://api.github.com/repos/vjeantet/alerter/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)"
    [[ -z "$ver" ]] && { err "Could not fetch alerter release URL"; return 1; }
    url="https://github.com/vjeantet/alerter/releases/download/${ver}/alerter-${ver#v}.zip"
    tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/alerter.zip"
    unzip -q "$tmp/alerter.zip" -d "$tmp"
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$tmp/alerter" "$HOME/.local/bin/alerter"
    # El binario viene de internet: quita la cuarentena de Gatekeeper.
    xattr -d com.apple.quarantine "$HOME/.local/bin/alerter" 2>/dev/null || true
    rm -rf "$tmp"
    ok "alerter installed"
  else
    ok "alerter already installed"
  fi
}

install_packages_linux() {
  step "Updating apt..."
  sudo apt-get update -qq

  step "Installing apt packages..."
  mapfile -t pkgs < <(grep -v '^\s*#' "$DOTFILES/packages/apt-packages.txt" | grep -v '^\s*$')
  sudo apt-get install -y "${pkgs[@]}"
  ok "apt packages installed"

  # bat ships as 'batcat' on Debian/Ubuntu
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    ok "Created bat → batcat symlink in ~/.local/bin"
  fi

  # fd ships as 'fdfind' on Debian/Ubuntu
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "Created fd → fdfind symlink in ~/.local/bin"
  fi

  install_linux_extras
}

# Packages not available in apt (or too outdated) — fetched from GitHub Releases
install_linux_extras() {
  local ver url tmp

  # neovim
  local NVIM_MIN="0.11.0"
  nvim_ver() { nvim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1; }
  ver_lt()   { printf '%s\n%s' "$1" "$2" | sort -V | head -1 | grep -qx "$1"; }

  if ! command -v nvim &>/dev/null || ver_lt "$(nvim_ver)" "$NVIM_MIN"; then
    step "Installing Neovim (latest)..."
    case "$ARCH" in
      x86_64)  url_asset="nvim-linux-x86_64.tar.gz" ;;
      aarch64) url_asset="nvim-linux-arm64.tar.gz"  ;;
      *) err "Unsupported arch: $ARCH"; return 1 ;;
    esac
    url="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest \
      | grep "browser_download_url" | grep "${url_asset}\"" | head -1 | cut -d'"' -f4)"
    [[ -z "$url" ]] && { err "Could not fetch Neovim release URL"; return 1; }
    curl -fsSL "$url" | sudo tar -xz -C /usr/local --strip-components=1
    ok "Neovim installed"
  else
    ok "Neovim $(nvim_ver) already installed"
  fi

  # git-delta
  if ! command -v delta &>/dev/null; then
    step "Installing git-delta..."
    ver="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)"
    case "$ARCH" in
      x86_64)  url="https://github.com/dandavison/delta/releases/download/${ver}/git-delta_${ver#v}_amd64.deb" ;;
      aarch64) url="https://github.com/dandavison/delta/releases/download/${ver}/git-delta_${ver#v}_arm64.deb" ;;
    esac
    tmp="$(mktemp)"
    curl -fsSL "$url" -o "$tmp"
    sudo dpkg -i "$tmp"
    rm -f "$tmp"
    ok "git-delta installed"
  else
    ok "git-delta already installed"
  fi

  # lazygit
  if ! command -v lazygit &>/dev/null; then
    step "Installing lazygit..."
    ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')"
    case "$ARCH" in
      x86_64)  url="https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_x86_64.tar.gz" ;;
      aarch64) url="https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_arm64.tar.gz" ;;
    esac
    tmp="$(mktemp -d)"
    curl -fsSL "$url" | tar -xz -C "$tmp"
    sudo install -m 755 "$tmp/lazygit" /usr/local/bin/lazygit
    rm -rf "$tmp"
    ok "lazygit installed"
  else
    ok "lazygit already installed"
  fi

  # eza
  if ! command -v eza &>/dev/null; then
    step "Installing eza..."
    ver="$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)"
    case "$ARCH" in
      x86_64)  url="https://github.com/eza-community/eza/releases/download/${ver}/eza_x86_64-unknown-linux-gnu.tar.gz" ;;
      aarch64) url="https://github.com/eza-community/eza/releases/download/${ver}/eza_aarch64-unknown-linux-gnu.tar.gz" ;;
    esac
    tmp="$(mktemp -d)"
    curl -fsSL "$url" | tar -xz -C "$tmp"
    sudo install -m 755 "$tmp/eza" /usr/local/bin/eza
    rm -rf "$tmp"
    ok "eza installed"
  else
    ok "eza already installed"
  fi

  # starship
  if ! command -v starship &>/dev/null; then
    step "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    ok "starship installed"
  else
    ok "starship already installed"
  fi

  # tldr (tealdeer) — not in apt on Debian/Raspbian
  if ! command -v tldr &>/dev/null; then
    step "Installing tldr (tealdeer)..."
    case "$ARCH" in
      x86_64)  url="https://github.com/dbrgn/tealdeer/releases/latest/download/tealdeer-linux-x86_64-musl" ;;
      aarch64) url="https://github.com/dbrgn/tealdeer/releases/latest/download/tealdeer-linux-arm-musleabihf" ;;
    esac
    sudo curl -fsSL "$url" -o /usr/local/bin/tldr
    sudo chmod +x /usr/local/bin/tldr
    ok "tldr installed"
  else
    ok "tldr already installed"
  fi

  # corepack — el paquete nodejs de apt ya no lo trae fiable; se instala vía npm global
  if ! command -v corepack &>/dev/null; then
    step "Installing corepack..."
    sudo npm install -g corepack
    ok "corepack installed"
  else
    ok "corepack already installed"
  fi

  # awscli v2 — apt solo trae v1 (obsoleto); instalador oficial de AWS
  if ! command -v aws &>/dev/null; then
    step "Installing AWS CLI v2..."
    case "$ARCH" in
      x86_64)  url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  ;;
      aarch64) url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
      *) err "Unsupported arch for awscli: $ARCH"; return 1 ;;
    esac
    tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/awscliv2.zip"
    unzip -q "$tmp/awscliv2.zip" -d "$tmp"
    sudo "$tmp/aws/install"
    rm -rf "$tmp"
    ok "AWS CLI installed"
  else
    ok "AWS CLI already installed"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Oh My Zsh
# ─────────────────────────────────────────────────────────────────────────────

install_omz() {
  # Install oh-my-zsh without changing shell or opening a new shell
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    step "Installing oh-my-zsh..."
    RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh installed"
  else
    ok "oh-my-zsh already installed"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # zsh-autosuggestions
  if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
    step "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "$custom/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
  else
    ok "zsh-autosuggestions already installed"
  fi

  # zsh-syntax-highlighting
  if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
    step "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "$custom/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
  else
    ok "zsh-syntax-highlighting already installed"
  fi

  # Set zsh as default shell
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" != "$zsh_path" ]]; then
    step "Setting zsh as default shell..."
    if grep -qx "$zsh_path" /etc/shells; then
      chsh -s "$zsh_path"
      ok "Default shell set to $zsh_path (takes effect on next login)"
    else
      warn "$zsh_path not in /etc/shells — add it manually and run: chsh -s $zsh_path"
    fi
  else
    ok "zsh is already the default shell"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# nvm
# ─────────────────────────────────────────────────────────────────────────────

install_nvm() {
  if [[ -d "$HOME/.nvm" ]]; then
    ok "nvm already installed ($HOME/.nvm)"
    return 0
  fi
  step "Installing nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
  ok "nvm installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Symlink helpers
# ─────────────────────────────────────────────────────────────────────────────

# Back up a file/dir that exists and is not a symlink to where we want.
backup_if_needed() {
  local dst="$1" src="$2"
  if [[ -L "$dst" ]]; then
    local current_target
    current_target="$(readlink "$dst")"
    # Accept only relative symlinks that resolve to src (what stow creates).
    # Absolute symlinks confuse stow's ownership check even when they point to
    # the right file — remove them so stow can recreate them as relative.
    if [[ "$current_target" != /* && "$(readlink -f "$dst" 2>/dev/null)" == "$src" ]]; then
      return 0   # already a correct relative symlink
    fi
    warn "Replacing stale/absolute symlink: $dst → $current_target"
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local rel="${dst#"$HOME/"}"
    warn "Backing up $dst → $BACKUP_DIR/$rel"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
  fi
}

# Stow a package, backing up any conflicting real files first.
# Usage: safe_stow <package> [target]
safe_stow() {
  local pkg="$1" target="${2:-$HOME}"
  step "Stowing $pkg..."

  while IFS= read -r -d '' src_file; do
    local rel="${src_file#"$DOTFILES/$pkg/"}"
    backup_if_needed "$target/$rel" "$src_file"
  done < <(find "$DOTFILES/$pkg" -type f -print0)

  stow --dir="$DOTFILES" --target="$target" --no-folding --restow "$pkg"
  ok "$pkg stowed"
}

# Create a single symlink safely (for cases stow doesn't cover, e.g. nvim/).
safe_link() {
  local src="$1" dst="$2"
  backup_if_needed "$dst" "$src"
  if [[ ! -e "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "Linked: $dst → $src"
  else
    ok "Already linked: $dst"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Error-resilient step runner
# ─────────────────────────────────────────────────────────────────────────────

FAILURES=()

# run_step NAME CMD [ARGS…]
# Runs CMD in an isolated subshell with errexit; on failure records the name
# and continues so the rest of the installation proceeds regardless.
run_step() {
  local name="$1"; shift
  if ( set -euo pipefail; "$@" ); then
    return 0
  else
    err "Step '$name' failed — continuing..."
    FAILURES+=("$name")
    return 0
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers for steps that contain inline logic
# ─────────────────────────────────────────────────────────────────────────────

setup_claude() {
  mkdir -p "$HOME/.claude/hooks"
  safe_stow claudeconfig
  chmod +x "$DOTFILES/claudeconfig/.claude/hooks/"*.sh 2>/dev/null || true
  ok "Claude hooks made executable"
}

switch_dotfiles_remote() {
  local remote_url
  remote_url="$(git -C "$DOTFILES" remote get-url origin 2>/dev/null || true)"
  if [[ "$remote_url" == https://github.com/* ]]; then
    local ssh_url="git@github.com:${remote_url#https://github.com/}"
    git -C "$DOTFILES" remote set-url origin "$ssh_url"
    ok "Switched dotfiles remote to SSH: $ssh_url"
  else
    ok "Dotfiles remote already uses SSH"
  fi
}

clear_system_motd() {
  if [[ -s /etc/motd ]]; then
    sudo truncate -s 0 /etc/motd
    ok "System MOTD cleared (/etc/motd)"
  else
    ok "System MOTD already empty"
  fi
}

setup_archive_downloads() {
  # macOS-only: archiva ~/Downloads a diario (script + LaunchAgent a las 03:00).
  local script_src="$DOTFILES/macos/archive-downloads.sh"
  local script_dst="$HOME/.local/bin/archive-downloads.sh"
  local plist_src="$DOTFILES/macos/com.fran.archive-downloads.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.fran.archive-downloads.plist"

  chmod +x "$script_src"
  safe_link "$script_src" "$script_dst"
  safe_link "$plist_src" "$plist_dst"

  # README de la política, visible en ~/Downloads (el script lo excluye del
  # barrido). Se copia solo si no existe, para no pisar ediciones manuales.
  if [[ -d "$HOME/Downloads" && ! -f "$HOME/Downloads/Downloads Policy.txt" ]]; then
    cp "$DOTFILES/macos/downloads-policy.txt" "$HOME/Downloads/Downloads Policy.txt"
    ok "Política copiada a ~/Downloads/Downloads Policy.txt"
  fi

  # Recargar el LaunchAgent de forma idempotente (unload + load -w).
  launchctl unload "$plist_dst" 2>/dev/null || true
  if launchctl load -w "$plist_dst" 2>/dev/null; then
    ok "LaunchAgent archive-downloads cargado (diario 03:00)"
  else
    warn "No se pudo cargar el LaunchAgent (¿sesión sin GUI?); se activará al iniciar sesión"
  fi
}

setup_scriptorium() {
  # macOS-only: servidor web local que sirve ~/src/html vía Caddy en :8080,
  # mantenido vivo por un LaunchAgent (RunAtLoad + KeepAlive). El acceso por
  # http://scriptorium (puerto 80) se habilita con sudo más abajo, vía
  # macos/scriptorium-root-setup.sh.
  local caddy_src="$DOTFILES/macos/scriptorium.Caddyfile"
  local caddy_dst="$HOME/.config/caddy/scriptorium.Caddyfile"
  local browse_src="$DOTFILES/macos/scriptorium-browse.html"
  local browse_dst="$HOME/.config/caddy/scriptorium-browse.html"
  local script_src="$DOTFILES/macos/scriptorium-serve.sh"
  local script_dst="$HOME/.local/bin/scriptorium-serve.sh"
  local plist_src="$DOTFILES/macos/com.fran.scriptorium.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.fran.scriptorium.plist"

  chmod +x "$script_src"
  safe_link "$caddy_src"  "$caddy_dst"
  safe_link "$browse_src" "$browse_dst"
  safe_link "$script_src" "$script_dst"
  safe_link "$plist_src"  "$plist_dst"

  # Recargar el LaunchAgent de forma idempotente (unload + load -w).
  launchctl unload "$plist_dst" 2>/dev/null || true
  if launchctl load -w "$plist_dst" 2>/dev/null; then
    ok "LaunchAgent scriptorium cargado (Caddy sirviendo ~/src/html en :8080)"
  else
    warn "No se pudo cargar el LaunchAgent scriptorium (¿sesión sin GUI?); se activará al iniciar sesión"
  fi

  # El puerto 80 y el nombre `scriptorium` requieren root. Solo pide sudo la
  # primera vez: si /etc/hosts ya resuelve el nombre, lo damos por configurado.
  if grep -qE "^[^#]*[[:space:]]scriptorium([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    ok "http://scriptorium (puerto 80) ya configurado"
  else
    warn "Habilitando http://scriptorium (puerto 80) — requiere sudo:"
    sudo bash "$DOTFILES/macos/scriptorium-root-setup.sh"
  fi
}

setup_scriptorium_share() {
  # macOS-only: bridge HTTP local (127.0.0.1:8737) para el botón «Compartir»
  # del scriptorium, mantenido vivo por un LaunchAgent (RunAtLoad + KeepAlive).
  # Expuesto al visor vía el proxy same-origin /-/* de scriptorium.Caddyfile
  # (ver setup_scriptorium); nunca fuera de localhost.
  local bridge_src="$DOTFILES/macos/scriptorium-share.py"
  local bridge_dst="$HOME/.local/bin/scriptorium-share.py"
  local script_src="$DOTFILES/macos/scriptorium-share-serve.sh"
  local script_dst="$HOME/.local/bin/scriptorium-share-serve.sh"
  local plist_src="$DOTFILES/macos/com.fran.scriptorium-share.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.fran.scriptorium-share.plist"

  chmod +x "$script_src"
  safe_link "$bridge_src" "$bridge_dst"
  safe_link "$script_src" "$script_dst"
  safe_link "$plist_src"  "$plist_dst"

  # Recargar el LaunchAgent de forma idempotente (unload + load -w).
  launchctl unload "$plist_dst" 2>/dev/null || true
  if launchctl load -w "$plist_dst" 2>/dev/null; then
    ok "LaunchAgent scriptorium-share cargado (bridge en 127.0.0.1:8737)"
  else
    warn "No se pudo cargar el LaunchAgent scriptorium-share (¿sesión sin GUI?); se activará al iniciar sesión"
  fi
}

copy_claude_template() {
  if [[ -d "$HOME/src" && ! -f "$HOME/src/CLAUDE.md" ]]; then
    cp "$DOTFILES/templates/CLAUDE.md" "$HOME/src/CLAUDE.md"
    ok "CLAUDE.md template copied to ~/src/"
  elif [[ ! -d "$HOME/src" ]]; then
    warn "~/src/ not found — CLAUDE.md template not copied (run: cp $DOTFILES/templates/CLAUDE.md ~/src/CLAUDE.md)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

step "Installing packages..."
if [[ "$PLATFORM" == "macos" ]]; then
  run_step "packages" install_packages_macos
else
  run_step "packages" install_packages_linux
fi

step "Installing oh-my-zsh and plugins..."
run_step "oh-my-zsh" install_omz

step "Installing nvm..."
run_step "nvm" install_nvm

step "Symlinking dotfiles..."

# git (.gitconfig, .gitignore_global → $HOME)
run_step "stow:git"   safe_stow git

# nvim (keep manual symlink — avoids restructuring the nvim/ directory)
run_step "link:nvim"  safe_link "$DOTFILES/nvim" "$HOME/.config/nvim"

# zsh (.zshrc → $HOME) — stow after omz so it overwrites the generated .zshrc
run_step "stow:zsh"   safe_stow zsh

# Claude Code (settings.json, hooks/ → $HOME/.claude/)
run_step "stow:claude" setup_claude

# Clear Debian's default MOTD (replaced by our Tolkien welcome)
if [[ "$PLATFORM" == "linux" ]]; then
  run_step "motd" clear_system_motd
fi

# macOS: LaunchAgent que archiva ~/Downloads a diario
if [[ "$PLATFORM" == "macos" ]]; then
  run_step "archive-downloads" setup_archive_downloads
fi

# macOS: servidor web local "scriptorium" (Caddy sirviendo ~/src/html en :8080)
if [[ "$PLATFORM" == "macos" ]]; then
  run_step "scriptorium" setup_scriptorium
fi

# macOS: bridge del botón «Compartir» del scriptorium (127.0.0.1:8737)
if [[ "$PLATFORM" == "macos" ]]; then
  run_step "scriptorium-share" setup_scriptorium_share
fi

# Switch dotfiles remote from HTTPS to SSH if needed
run_step "git-remote" switch_dotfiles_remote

# CLAUDE.md template — copy to ~/src/ only if it doesn't exist yet
run_step "claude-template" copy_claude_template

echo ""
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo -e "${GRN}✓ Dotfiles installed successfully!${RST}"
else
  echo -e "${YEL}⚠ Installed with ${#FAILURES[@]} failure(s):${RST}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${RED}✗ $f${RST}"
  done
  echo ""
  echo -e "  Fix the issues above and re-run ${CYN}./install.sh${RST}"
fi

echo ""
echo "  Next steps:"
echo "  1. Log out and back in so zsh becomes the active shell"
echo "  2. Launch nvim — lazy.nvim will install plugins on first run"
echo "  3. Edit ~/src/CLAUDE.md to customize for your projects"
[[ -n "${BACKUP_DIR:-}" && -d "${BACKUP_DIR:-}" ]] && \
  echo "  4. Backups of replaced files: $BACKUP_DIR"
