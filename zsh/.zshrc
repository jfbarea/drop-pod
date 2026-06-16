# ── Terminal compatibility ─────────────────────────────────────────────────────
# If the remote doesn't have the terminfo for the current TERM (e.g. xterm-ghostty),
# fall back to xterm-256color to avoid cursor rendering bugs.
if ! infocmp "$TERM" &>/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using starship

plugins=(
  git
)

source "$ZSH/oh-my-zsh.sh"

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── NVM ───────────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── History ───────────────────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# ── Aliases ───────────────────────────────────────────────────────────────────
alias vim="nvim"
alias vi="nvim"

if command -v eza &>/dev/null; then
  alias ls="eza --icons"
  alias ll="eza -lah --icons --git"
  alias lt="eza --tree --icons"
fi

if command -v bat &>/dev/null; then
  alias cat="bat --paging=never"
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
# Sirve el directorio actual por HTTP. Auto-busca puerto libre desde 8642.
serve() {
  local port="${1:-8642}"
  while command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":$port "; do
    port=$((port + 1))
  done
  local ip
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo "→ http://localhost:$port"
  [[ -n "$ip" ]] && echo "→ http://$ip:$port  (LAN)"
  python3 -m http.server "$port"
}

# ── Zoxide ────────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ── Starship ──────────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi
# ── NTFY ──────────────────────────────────────────────────────────────────
export NTFY_TOPIC=sabes-que-notificacion   # Claude Code notifications

# ── Claude Code helpers ───────────────────────────────────────────────────
[[ -f "$HOME/.config/zsh/claude-helpers.sh" ]] && source "$HOME/.config/zsh/claude-helpers.sh"

# ── Bienvenida Tolkien (toda shell interactiva fuera de tmux) ─────────────
[[ -z "${TMUX:-}" && -f "$HOME/.motd.sh" ]] && source "$HOME/.motd.sh"
export PATH="$HOME/.local/bin:$PATH"
