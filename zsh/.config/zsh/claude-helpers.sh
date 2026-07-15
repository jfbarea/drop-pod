# Greenfield: crea carpeta en ~/src, repo y deja todo listo para /scaffold
claude-new() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Uso: claude-new <nombre>" >&2
    return 1
  fi
  mkdir -p ~/src/"$name" && cd ~/src/"$name" || return 1
  git init -q
  echo "Repo creado en ~/src/$name. Lanza 'claude' y ejecuta /scaffold"
}

# Cuenta personal de Claude en ~/src/fran y subdirectorios.
# Dentro de ese árbol usa un config dir aparte (~/.claude-personal) con su
# propio login de suscripción personal; fuera de él, la config global normal.
claude() {
  local personal_root="${HOME:A}/src/fran"
  case "${PWD:A}/" in
    "$personal_root"/*)
      CLAUDE_CONFIG_DIR="$HOME/.claude-personal" \
      CLAUDE_CODE_OAUTH_TOKEN="$(<$HOME/.claude-personal/token)" \
      command claude "$@" ;;
    *)
      CLAUDE_CODE_OAUTH_TOKEN="$(<$HOME/.claude/token)" \
      command claude "$@" ;;
  esac
}
