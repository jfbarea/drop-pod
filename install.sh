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
  brew bundle --file="$DOTFILES/packages/Brewfile" --no-lock
  ok "Homebrew packages ready"
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
# Symlink helpers
# ─────────────────────────────────────────────────────────────────────────────

# Back up a file/dir that exists and is not a symlink to where we want.
backup_if_needed() {
  local dst="$1" src="$2"
  if [[ -L "$dst" ]]; then
    local current_target
    current_target="$(readlink "$dst")"
    if [[ "$current_target" == "$src" ]]; then
      return 0   # already correct
    fi
    warn "Replacing stale symlink: $dst → $current_target"
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
# Main
# ─────────────────────────────────────────────────────────────────────────────

step "Installing packages..."
if [[ "$PLATFORM" == "macos" ]]; then
  install_packages_macos
else
  install_packages_linux
fi

step "Installing oh-my-zsh and plugins..."
install_omz

step "Symlinking dotfiles..."

# git (.gitconfig, .gitignore_global → $HOME)
safe_stow git

# nvim (keep manual symlink — avoids restructuring the nvim/ directory)
safe_link "$DOTFILES/nvim" "$HOME/.config/nvim"

# zsh (.zshrc → $HOME) — stow after omz so it overwrites the generated .zshrc
safe_stow zsh

# Claude Code (settings.json, hooks/ → $HOME/.claude/)
mkdir -p "$HOME/.claude/hooks"
safe_stow claude
chmod +x "$DOTFILES/claude/.claude/hooks/"*.sh 2>/dev/null || true
ok "Claude hooks made executable"

# CLAUDE.md template — copy to ~/src/ only if it doesn't exist yet
if [[ -d "$HOME/src" && ! -f "$HOME/src/CLAUDE.md" ]]; then
  cp "$DOTFILES/templates/CLAUDE.md" "$HOME/src/CLAUDE.md"
  ok "CLAUDE.md template copied to ~/src/"
elif [[ ! -d "$HOME/src" ]]; then
  warn "~/src/ not found — CLAUDE.md template not copied (run: cp $DOTFILES/templates/CLAUDE.md ~/src/CLAUDE.md)"
fi

echo ""
echo -e "${GRN}✓ Dotfiles installed successfully!${RST}"
echo ""
echo "  Next steps:"
echo "  1. Add to ~/.zshrc (before the starship eval):"
echo "       export NTFY_TOPIC=sabes-que-notificación   # Claude Code notifications"
echo "  2. Log out and back in so zsh becomes the active shell"
echo "  3. Launch nvim — lazy.nvim will install plugins on first run"
echo "  4. Edit ~/src/CLAUDE.md to customize for your projects"
[[ -n "${BACKUP_DIR:-}" && -d "${BACKUP_DIR:-}" ]] && \
  echo "  4. Backups of replaced files: $BACKUP_DIR"
