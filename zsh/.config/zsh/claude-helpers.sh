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
