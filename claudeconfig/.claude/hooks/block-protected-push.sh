#!/usr/bin/env bash
set -uo pipefail

PROTECTED_BRANCHES="${CLAUDE_PROTECTED_BRANCHES:-main master dev develop development alpha}"

payload="$(cat)"
command_line="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
hook_cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""')"
[[ -d "$hook_cwd" ]] || hook_cwd="$PWD"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

deny_protected() {
  deny "git push a la rama protegida '$1' esta prohibido (politica del usuario: $PROTECTED_BRANCHES). El push a ramas protegidas es manual; en ramas de trabajo si puedes pushear."
}

deny_unknown() {
  deny "git push bloqueado: no puedo determinar a que rama apunta ($1), y las ramas protegidas ($PROTECTED_BRANCHES) no se pushean. Usa un refspec explicito, p. ej. 'git push origin mi-rama'."
}

looks_like_push() {
  printf '%s' "$1" | grep -Eq '(^|[^[:alnum:]_./-])git(([[:space:]]+-C[[:space:]]+[^[:space:]]+)|([[:space:]]+-c[[:space:]]+[^[:space:]]+)|([[:space:]]+--?[^[:space:]]+))*[[:space:]]+push([[:space:]]|$)'
}

is_protected() {
  local candidate branch
  candidate="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for branch in $PROTECTED_BRANCHES; do
    [[ "$candidate" == "$branch" ]] && return 0
  done
  return 1
}

current_branch() {
  git --no-optional-locks -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null
}

check_target_branch() {
  local target="$1" repo_dir="$2"
  case "$target" in
    refs/tags/*) return 0 ;;
  esac
  target="${target#+}"
  target="${target#refs/heads/}"
  if [[ "$target" == "HEAD" || -z "$target" ]]; then
    target="$(current_branch "$repo_dir")"
    [[ -z "$target" || "$target" == "HEAD" ]] && deny_unknown "HEAD en '$repo_dir' no resuelve a una rama"
  fi
  case "$target" in
    *'*'* | *'?'*) deny_unknown "el refspec '$1' es un patron" ;;
  esac
  is_protected "$target" && deny_protected "$target"
  return 0
}

check_segment() {
  local segment="$1"
  case "$segment" in
    *'$('* | *'`'* | *'$'*) deny_unknown "el comando expande variables o subshells: $segment" ;;
  esac

  local -a tokens=()
  read -ra tokens <<< "$(printf '%s' "$segment" | tr -d "\"'")"

  local repo_dir="$hook_cwd" index=0 total=${#tokens[@]}
  while (( index < total )) && [[ "${tokens[index]}" != "push" ]]; do
    [[ "${tokens[index]}" == "-C" && $((index + 1)) -lt $total ]] && repo_dir="${tokens[index + 1]}"
    index=$((index + 1))
  done
  (( index >= total )) && deny_unknown "no encuentro los argumentos de push en: $segment"
  [[ -d "$repo_dir" ]] || repo_dir="$hook_cwd"

  local -a positionals=()
  local pushes_tags=0 token
  index=$((index + 1))
  while (( index < total )); do
    token="${tokens[index]}"
    case "$token" in
      --all | --mirror)
        deny "git push $token empujaria todas las ramas, incluidas las protegidas ($PROTECTED_BRANCHES). Pushea una rama concreta." ;;
      --tags) pushes_tags=1 ;;
      -o | --push-option | --repo | --receive-pack | --exec) index=$((index + 1)) ;;
      -*) ;;
      *) positionals+=("$token") ;;
    esac
    index=$((index + 1))
  done

  if (( ${#positionals[@]} > 1 )); then
    local refspec
    for refspec in "${positionals[@]:1}"; do
      check_target_branch "${refspec##*:}" "$repo_dir"
    done
    return 0
  fi

  (( pushes_tags )) && return 0

  local branch
  branch="$(current_branch "$repo_dir")"
  [[ -z "$branch" || "$branch" == "HEAD" ]] && deny_unknown "'$repo_dir' no esta en una rama"
  is_protected "$branch" && deny_protected "$branch"
  return 0
}

looks_like_push "$command_line" || exit 0

while IFS= read -r segment; do
  looks_like_push "$segment" && check_segment "$segment"
done <<< "$(printf '%s' "$command_line" | sed -E 's/\|\|/;/g; s/&&/;/g' | tr ';|&' '\n\n\n')"

exit 0
