# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Using starship

plugins=(
  git
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

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

# ── Zoxide ────────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ── Starship ──────────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi
