#!/bin/sh

input=$(cat)

TAB=$(printf '\t')
IFS="$TAB" read -r cwd model ctx_pct ctx_used ctx_size rl5 rl7 <<EOF
$(printf '%s' "$input" | jq -r '[
  (.workspace.current_dir // .cwd // ""),
  (.model.display_name // ""),
  (.context_window.used_percentage // -1),
  (.context_window.total_input_tokens // -1),
  (.context_window.context_window_size // -1),
  (.rate_limits.five_hour.used_percentage // -1),
  (.rate_limits.seven_day.used_percentage // -1)
] | @tsv')
EOF

esc=$(printf '\033')
reset="${esc}[0m"
dim_cyan="${esc}[2;36m"
dim_magenta="${esc}[2;35m"
dim_yellow="${esc}[2;33m"
dim_gray="${esc}[2;37m"
warn="${esc}[33m"
crit="${esc}[31m"

pct_color() {
  if [ "$1" -ge 80 ]; then printf '%s' "$crit"
  elif [ "$1" -ge 60 ]; then printf '%s' "$warn"
  else printf '%s' "$dim_gray"
  fi
}

fmt_tokens() {
  n=$1
  if [ "$n" -ge 1000000 ]; then
    whole=$((n / 1000000))
    frac=$(((n % 1000000 + 50000) / 100000))
    if [ "$frac" -ge 10 ]; then whole=$((whole + 1)); frac=0; fi
    if [ "$frac" -eq 0 ]; then printf '%dM' "$whole"; else printf '%d.%dM' "$whole" "$frac"; fi
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' $((n / 1000))
  else
    printf '%d' "$n"
  fi
}

git_root=""
if [ -d "$cwd" ]; then
  git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
fi

if [ -n "$git_root" ]; then
  rel=${cwd#"$git_root"}
  rel=${rel#/}
  if [ -n "$rel" ]; then
    dir_disp="$(basename "$git_root")/$rel"
  else
    dir_disp=$(basename "$git_root")
  fi
else
  disp="$cwd"
  case "$disp" in
    "$HOME") disp="~" ;;
    "$HOME"/*) disp="~${disp#"$HOME"}" ;;
  esac
  dir_disp=$(printf '%s' "$disp" | awk -F/ '{n=NF; if(n>3){print $(n-2)"/"$(n-1)"/"$n} else {print}}')
fi

branch=""
git_extra=""
if [ -n "$git_root" ]; then
  summary=$(git -C "$cwd" --no-optional-locks status --porcelain=2 --branch 2>/dev/null | awk '
    BEGIN{branch="";ahead=0;behind=0;staged=0;modified=0;untracked=0;conflicted=0}
    $1=="#" && $2=="branch.head"{branch=$3}
    $1=="#" && $2=="branch.oid"{oid=substr($3,1,7)}
    $1=="#" && $2=="branch.ab"{a=$3;b=$4;gsub(/\+/,"",a);gsub(/-/,"",b);ahead=a+0;behind=b+0}
    $1=="1"||$1=="2"{x=substr($2,1,1); y=substr($2,2,1); if(x!=".")staged=1; if(y!=".")modified=1}
    $1=="u"{conflicted=1}
    $1=="?"{untracked=1}
    END{if(branch=="(detached)")branch=oid; printf "%s|%s|%s|%s|%s|%s|%s", branch, ahead, behind, staged, modified, untracked, conflicted}
  ')
  branch=${summary%%|*}; rest=${summary#*|}
  ahead=${rest%%|*}; rest=${rest#*|}
  behind=${rest%%|*}; rest=${rest#*|}
  staged=${rest%%|*}; rest=${rest#*|}
  modified=${rest%%|*}; rest=${rest#*|}
  untracked=${rest%%|*}; conflicted=${rest#*|}

  ind=""
  [ "$conflicted" = "1" ] && ind="${ind}="
  [ "$ahead" != "0" ] && ind="${ind}⇡${ahead}"
  [ "$behind" != "0" ] && ind="${ind}⇣${behind}"
  [ "$staged" = "1" ] && ind="${ind}+"
  [ "$modified" = "1" ] && ind="${ind}!"
  [ "$untracked" = "1" ] && ind="${ind}?"
  [ -n "$ind" ] && git_extra="${dim_yellow} [${ind}]${reset}"
fi

line="${dim_cyan}${dir_disp}${reset}"
[ -n "$branch" ] && line="${line} ${dim_magenta}${branch}${reset}${git_extra}"
[ -n "$model" ] && line="${line} ${dim_gray}${model}${reset}"

if [ "$ctx_pct" -ge 0 ] 2>/dev/null; then
  c=$(pct_color "$ctx_pct")
  ctx="ctx ${ctx_pct}%"
  if [ "$ctx_used" -ge 0 ] 2>/dev/null && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
    ctx="${ctx} $(fmt_tokens "$ctx_used")/$(fmt_tokens "$ctx_size")"
  fi
  line="${line} ${dim_gray}·${reset} ${c}${ctx}${reset}"
fi

rl=""
if [ "$rl5" -ge 0 ] 2>/dev/null; then
  rl="$(pct_color "$rl5")5h ${rl5}%${reset}"
fi
if [ "$rl7" -ge 0 ] 2>/dev/null; then
  [ -n "$rl" ] && rl="${rl}${dim_gray} · ${reset}"
  rl="${rl}$(pct_color "$rl7")7d ${rl7}%${reset}"
fi
[ -n "$rl" ] && line="${line} ${dim_gray}·${reset} ${rl}"

printf '%s' "$line"
