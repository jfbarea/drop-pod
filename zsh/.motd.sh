#!/usr/bin/env bash
# Tolkien welcome — sourced by .zshrc en cada shell interactiva fuera de tmux.
# Compatible con Linux (raspi, debian) y macOS.

_B='\033[1m'; _I='\033[3m'; _D='\033[2m'
_C='\033[0;36m'; _G='\033[0;32m'; _Y='\033[1;33m'; _R='\033[0m'

_sep() {
  printf "${_D}  ────────────────────────────────────────────────────────${_R}\n"
}

_bar() {
  local p=$1 w=10 f e
  (( p > 100 )) && p=100
  f=$(( p * w / 100 )); e=$(( w - f ))
  printf "${_G}"
  for ((i=0;i<f;i++)); do printf '█'; done
  printf "${_D}"
  for ((i=0;i<e;i++)); do printf '░'; done
  printf "${_R}"
}

# ── Quote ─────────────────────────────────────────────────────────────────
_qf="$HOME/.tolkien_quotes"
if [[ -f "$_qf" ]]; then
  if command -v shuf &>/dev/null; then
    _qline="$(shuf -n 1 "$_qf")"
  else
    # macOS no trae shuf por defecto — fallback con awk
    _qline="$(awk 'BEGIN{srand()} {a[NR]=$0} END{print a[int(rand()*NR)+1]}' "$_qf")"
  fi
  IFS='|' read -r _qt _at <<< "$_qline"
  printf '\n'
  _sep
  printf '\n'
  while IFS= read -r _ql; do
    printf "    ${_B}%s${_R}\n" "$_ql"
  done < <(fold -s -w 54 <<< "$_qt")
  printf "\n    ${_D}${_I}— %s${_R}\n\n" "$_at"
  _sep
fi

# ── System info ───────────────────────────────────────────────────────────
_os_kind="$(uname -s)"
_host="$(hostname -s)"
_kern="$(uname -r | cut -d+ -f1)"

if [[ "$_os_kind" == "Darwin" ]]; then
  # macOS
  _os="$(sw_vers -productName) $(sw_vers -productVersion)"

  _btime=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[= ,]' '{print $6}')
  if [[ -n "$_btime" ]]; then
    _sec=$(( $(date +%s) - _btime ))
    _d=$(( _sec / 86400 )); _h=$(( (_sec % 86400) / 3600 )); _m=$(( (_sec % 3600) / 60 ))
    _up=""
    (( _d > 0 )) && _up="${_d}d "
    (( _h > 0 )) && _up="${_up}${_h}h "
    _up="${_up}${_m}m"
  else
    _up='?'
  fi

  _load="$(sysctl -n vm.loadavg 2>/dev/null | awk '{printf "%s %s %s", $2, $3, $4}')"
  _l1="$(awk '{print $1}' <<< "$_load")"

  _ip=""
  for _iface in en0 en1 en2; do
    _ip="$(ipconfig getifaddr "$_iface" 2>/dev/null)" && [[ -n "$_ip" ]] && break
  done

  # Memoria: total via sysctl, libre via vm_stat (page size + free/inactive)
  _mt=$(( $(sysctl -n hw.memsize) / 1024 ))   # KB total
  _ps=$(vm_stat | awk '/page size of/{print $8}')
  [[ -z "$_ps" ]] && _ps=4096
  _free_pg=$(vm_stat | awk '/Pages free/{gsub(/\./,"",$3); print $3}')
  _inact_pg=$(vm_stat | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')
  _ma=$(( ( _free_pg + _inact_pg ) * _ps / 1024 ))  # KB disponibles

  _nc=$(sysctl -n hw.ncpu)
  _tmp=''
else
  # Linux
  _os="$(. /etc/os-release 2>/dev/null && printf '%s %s' "$NAME" "$VERSION_ID" || echo Linux)"
  _up="$(uptime -p 2>/dev/null \
    | sed 's/up //;s/ days\?/d/g;s/ hours\?/h/g;s/ minutes\?/m/g;s/, / /g' \
    || echo '?')"
  _load="$(awk '{print $1, $2, $3}' /proc/loadavg)"
  _l1="$(awk '{print $1}' /proc/loadavg)"
  _ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  _mt="$(awk '/MemTotal/{print $2}'     /proc/meminfo)"
  _ma="$(awk '/MemAvailable/{print $2}' /proc/meminfo)"
  _nc="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)"
  _tmp=''
  [[ -f /sys/class/thermal/thermal_zone0/temp ]] && \
    _tmp="$(( $(< /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
fi

# Cálculos comunes
_mu=$(( (_mt - _ma) / 1024 ))     # MB usados
_mtm=$(( _mt / 1024 ))             # MB totales
_mp=$(( (_mt - _ma) * 100 / _mt ))

_du="$(df -h / | awk 'NR==2{print $3}')"
_dt="$(df -h / | awk 'NR==2{print $2}')"
_dp="$(df / | awk 'NR==2{printf "%d", $3*100/($3+$4)}')"

_cp="$(awk -v l="$_l1" -v n="$_nc" 'BEGIN{p=int(l/n*100); print (p>100?100:p)}')"

printf '\n'
printf "  ${_C}%-8s${_R}%-22s  ${_C}%-8s${_R}%s\n" "host"   "$_host"  "uptime"  "$_up"
printf "  ${_C}%-8s${_R}%-22s  ${_C}%-8s${_R}%s\n" "os"     "$_os"    "load"    "$_load"
printf "  ${_C}%-8s${_R}%-22s  ${_C}%-8s${_R}%s\n" "kernel" "$_kern"  "ip"      "$_ip"
printf '\n'
printf "  ${_C}cpu   ${_R}$(_bar "$_cp")  ${_Y}%3d%%${_R}" "$_cp"
[[ -n "$_tmp" ]] && printf "   %s" "$_tmp"
printf '\n'
printf "  ${_C}ram   ${_R}$(_bar "$_mp")  ${_Y}%3d%%${_R}   %d MB / %d MB\n" "$_mp" "$_mu" "$_mtm"
printf "  ${_C}disk  ${_R}$(_bar "$_dp")  ${_Y}%3d%%${_R}   %s / %s\n"       "$_dp" "$_du" "$_dt"
printf '\n'
_sep
printf '\n'

unset _B _I _D _C _G _Y _R
unset _qf _qt _at _ql _qline _host _os _kern _up _load _ip _os_kind
unset _btime _sec _d _h _m _ps _free_pg _inact_pg _iface
unset _mt _ma _mu _mtm _mp _du _dt _dp _nc _l1 _cp _tmp
