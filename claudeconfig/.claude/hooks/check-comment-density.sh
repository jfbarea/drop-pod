#!/usr/bin/env bash
set -uo pipefail

MAX_ADDED="${CLAUDE_COMMENT_MAX_ADDED:-3}"
MAX_RATIO="${CLAUDE_COMMENT_MAX_RATIO:-25}"
RATIO_MIN_LINES="${CLAUDE_COMMENT_RATIO_MIN_LINES:-10}"

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')"

case "$tool" in
  Write | Edit) ;;
  *) exit 0 ;;
esac

comment_pattern() {
  case "${1##*.}" in
    sh | bash | zsh | py | rb | pl) printf '^[[:space:]]*#' ;;
    js | jsx | mjs | cjs | ts | tsx | go | rs | java | kt | swift | c | h | cpp | hpp | cc | php | scala | dart | css | scss)
      printf '^[[:space:]]*(//|/\*|\*)' ;;
    lua | sql | hs) printf '^[[:space:]]*--' ;;
    *) return 1 ;;
  esac
}

pattern="$(comment_pattern "$file")" || exit 0

count_comments() {
  [[ -z "$1" ]] && { printf '0'; return; }
  printf '%s\n' "$1" | grep -v '^#!' | grep -Ec "$pattern" || true
}

count_lines() {
  [[ -z "$1" ]] && { printf '0'; return; }
  printf '%s\n' "$1" | grep -c '' || true
}

if [[ "$tool" == "Write" ]]; then
  new_text="$(printf '%s' "$payload" | jq -r '.tool_input.content // ""')"
  old_text=""
else
  new_text="$(printf '%s' "$payload" | jq -r '.tool_input.new_string // ""')"
  old_text="$(printf '%s' "$payload" | jq -r '.tool_input.old_string // ""')"
fi

added_comments=$(( $(count_comments "$new_text") - $(count_comments "$old_text") ))
added_lines=$(( $(count_lines "$new_text") - $(count_lines "$old_text") ))

(( added_comments > 0 )) || exit 0

trips=0
(( added_comments >= MAX_ADDED )) && trips=1
if (( added_lines >= RATIO_MIN_LINES )) && (( added_comments * 100 / added_lines > MAX_RATIO )); then
  trips=1
fi
(( trips )) || exit 0

name="$(basename "$file")"
summary="$added_comments líneas de comentario nuevas en $name"
(( added_lines > 0 )) && summary="$summary ($added_comments de $added_lines líneas añadidas)"

jq -n \
  --arg msg "⚠︎ $summary — revisa si cumplen la regla de comentarios." \
  --arg ctx "El hook de densidad de comentarios ha saltado: $summary.

Relee lo que acabas de escribir y borra todo comentario que no sea una de las cuatro clases
permitidas por el CLAUDE.md del usuario:
  1. hechos del entorno externo, con el dato concreto (versión, error literal, nombre por distro);
  2. alternativas descartadas y por qué;
  3. invariantes no locales (orden obligatorio, precondiciones del caller);
  4. marcadores de rareza intencionada.

Todo lo que describa QUÉ hace el código se borra y, si hace falta, se arregla renombrando o
extrayendo. El porqué del diseño propio va al mensaje de commit, no al código. Si el recuento es
legítimo, sigue sin comentar nada: este aviso no exige respuesta." \
  '{
    systemMessage: $msg,
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'

# PostToolUse no honra el exit 2 (la escritura ya ocurrió): el aviso es la única salida posible.
exit 0
