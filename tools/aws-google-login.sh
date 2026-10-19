#!/usr/bin/env bash
# Acceso a la CLI de AWS con la cuenta de Google Workspace (federación SAML con saml2aws).
#
# Uso: bash aws-google-login.sh
#   - La primera vez instala saml2aws y awscli, configura el perfil y hace login.
#   - Las siguientes solo hace login (la sesión dura 1 h). Volver a ejecutarlo es la forma de renovarla.
#
# Funciona en macOS, Linux, WSL y Git Bash (Windows).
set -euo pipefail

# Rellenar antes de compartir el script. Si se dejan vacíos, se piden al ejecutarlo.
SAML_URL=""          # enlace del icono de AWS en el menú de apps de Google (botón derecho → copiar enlace)
AWS_PROFILE_NAME=""  # p. ej. empresa-dev
AWS_REGION="eu-west-1"

SAML2AWS_VERSION="2.36.19"
SAML2AWS_SHA256="
95ea25517e283397009ffb512b0d72b65e11aa7fc18cc0c4558f09d29224caf9  saml2aws_2.36.19_darwin_amd64.tar.gz
a243b1453c41930b0083b5841658ab8b4186dfa5a0e71a724159884634d79644  saml2aws_2.36.19_darwin_arm64.tar.gz
891f7d0eb89bb3000aca72f70ef244ea5f24894f33b24143203caa528555ad7f  saml2aws_2.36.19_linux_amd64.tar.gz
b62424836c8ebd41dca312f3385a7ed552b48dafd4c49d47f62bbef428633255  saml2aws_2.36.19_linux_arm64.tar.gz
739bd99db011825521cf7adb15c205e7aac6570f8b74cd0afc5bedbb0804a0eb  saml2aws_2.36.19_windows_amd64.zip
7872b44600b1e3b03c1a1d82216f4dcca9a632ecfce8af43076d3bfb88616295  saml2aws_2.36.19_windows_arm64.zip
"

BOLD='\033[1m'; GRN='\033[0;32m'; YEL='\033[1;33m'; RED='\033[0;31m'; RST='\033[0m'
step() { printf "\n${BOLD}▸ %s${RST}\n" "$*"; }
ok()   { printf "  ${GRN}✓${RST} %s\n" "$*"; }
warn() { printf "  ${YEL}!${RST} %s\n" "$*"; }
die()  { printf "  ${RED}✗${RST} %s\n" "$*" >&2; exit 1; }

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=darwin ;;
    Linux) OS=linux ;;
    MINGW* | MSYS* | CYGWIN*) OS=windows ;;
    *) die "Sistema no soportado: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    arm64 | aarch64) ARCH=arm64 ;;
    *) die "Arquitectura no soportada: $(uname -m)" ;;
  esac
  if [[ "$OS" == windows ]]; then
    BIN_DIR="$HOME/bin"
  else
    BIN_DIR="$HOME/.local/bin"
  fi
  mkdir -p "$BIN_DIR"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) PATH="$BIN_DIR:$PATH" ;; esac
}

need() { command -v "$1" >/dev/null 2>&1 || die "Falta '$1'. Instálalo y vuelve a ejecutar el script."; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

unzip_to() {
  local zip="$1" dest="$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -oq "$zip" -d "$dest"
  elif [[ "$OS" == windows ]]; then
    # Git for Windows no trae unzip; PowerShell sí está siempre.
    powershell.exe -NoProfile -Command \
      "Expand-Archive -Force -Path '$(cygpath -w "$zip")' -DestinationPath '$(cygpath -w "$dest")'"
  else
    die "Falta 'unzip' (en Debian/Ubuntu: sudo apt install unzip)."
  fi
}

persist_bin_dir() {
  local rc line="export PATH=\"$BIN_DIR:\$PATH\""
  case "${SHELL:-}" in
    */zsh) rc="$HOME/.zshrc" ;;
    *) rc="$HOME/.bashrc" ;;
  esac
  if ! grep -qsF "$line" "$rc"; then
    printf '\n%s\n' "$line" >>"$rc"
    warn "Añadido $BIN_DIR al PATH en $rc (abre una terminal nueva para que se aplique)."
  fi
}

install_saml2aws() {
  step "saml2aws"
  if command -v saml2aws >/dev/null 2>&1; then
    ok "ya instalado ($(saml2aws --version 2>&1))"
    return
  fi
  if [[ "$OS" == darwin ]] && command -v brew >/dev/null 2>&1; then
    brew install saml2aws
    ok "instalado con Homebrew"
    return
  fi

  need curl
  local ext=tar.gz
  [[ "$OS" == windows ]] && ext=zip
  local asset="saml2aws_${SAML2AWS_VERSION}_${OS}_${ARCH}.${ext}"
  local expected
  expected="$(printf '%s\n' "$SAML2AWS_SHA256" | awk -v a="$asset" '$2 == a { print $1 }')"
  [[ -n "$expected" ]] || die "No hay binario de saml2aws para $OS/$ARCH."

  curl -fsSL -o "$TMP/$asset" \
    "https://github.com/Versent/saml2aws/releases/download/v${SAML2AWS_VERSION}/$asset"
  [[ "$(sha256_of "$TMP/$asset")" == "$expected" ]] || die "El checksum de $asset no coincide."

  if [[ "$ext" == zip ]]; then
    unzip_to "$TMP/$asset" "$TMP"
    mv -f "$TMP/saml2aws.exe" "$BIN_DIR/"
  else
    tar -xzf "$TMP/$asset" -C "$TMP" saml2aws
    install -m 0755 "$TMP/saml2aws" "$BIN_DIR/saml2aws"
  fi
  [[ "$OS" == windows ]] || persist_bin_dir
  ok "instalado en $BIN_DIR"
}

install_awscli() {
  step "AWS CLI"
  if command -v aws >/dev/null 2>&1; then
    ok "ya instalada ($(aws --version 2>&1 | cut -d' ' -f1))"
    return
  fi

  case "$OS" in
    darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install awscli
      else
        need curl
        curl -fsSL -o "$TMP/AWSCLIV2.pkg" "https://awscli.amazonaws.com/AWSCLIV2.pkg"
        warn "El instalador de AWS pide la contraseña del Mac."
        sudo installer -pkg "$TMP/AWSCLIV2.pkg" -target /
      fi
      ;;
    linux)
      need curl
      local machine
      machine="$(uname -m)"
      [[ "$machine" == arm64 ]] && machine=aarch64
      curl -fsSL -o "$TMP/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-${machine}.zip"
      unzip_to "$TMP/awscliv2.zip" "$TMP"
      "$TMP/aws/install" --update -i "$HOME/.local/aws-cli" -b "$BIN_DIR"
      persist_bin_dir
      ;;
    windows)
      command -v winget.exe >/dev/null 2>&1 ||
        die "Instala la AWS CLI con https://awscli.amazonaws.com/AWSCLIV2.msi y vuelve a ejecutar el script."
      warn "Windows pedirá permisos de administrador para instalar la AWS CLI."
      winget.exe install -e --id Amazon.AWSCLI --accept-package-agreements --accept-source-agreements
      # El PATH de esta sesión de Git Bash no ve lo que acaba de instalar el MSI.
      PATH="/c/Program Files/Amazon/AWSCLIV2:$PATH"
      ;;
  esac
  command -v aws >/dev/null 2>&1 || die "La AWS CLI no aparece en el PATH tras instalarla. Abre una terminal nueva y reintenta."
  ok "instalada"
}

ini_value() {
  [[ -f "$HOME/.saml2aws" ]] || return 0
  awk -v k="$1" '$1 == k { sub(/^[^=]*= */, ""); print; exit }' "$HOME/.saml2aws"
}

ask() {
  local prompt="$1" default="$2" answer
  if [[ -n "$default" ]]; then
    read -r -p "  $prompt [$default]: " answer
    printf '%s' "${answer:-$default}"
  else
    while [[ -z "${answer:-}" ]]; do read -r -p "  $prompt: " answer; done
    printf '%s' "$answer"
  fi
}

configure() {
  step "Configuración"
  local url="${SAML_URL:-$(ini_value url)}"
  local profile="${AWS_PROFILE_NAME:-$(ini_value aws_profile)}"
  local username
  [[ -n "$url" ]] || url="$(ask 'Enlace de la app AWS en Google (botón derecho → copiar enlace)' '')"
  [[ -n "$profile" ]] || profile="$(ask 'Nombre del perfil de AWS' '')"
  username="$(ask 'Email de Google' "$(ini_value username)")"

  local out
  out="$(saml2aws configure \
    --idp-provider GoogleApps \
    --mfa Auto \
    --url "$url" \
    --username "$username" \
    --profile "$profile" \
    --session-duration 3600 \
    --skip-prompt 2>&1)" || die "saml2aws configure falló:
$out"
  aws configure set region "$AWS_REGION" --profile "$profile"
  PROFILE="$profile"
  ok "perfil '$PROFILE' en $AWS_REGION"
}

login() {
  step "Login con Google"
  # Sin --skip-prompt a propósito: en 2.36.19 también se salta la pregunta de la contraseña y la toma
  # del llavero; en una máquina limpia falla con "Error validating login details.: Empty password".
  local cmd=(saml2aws login)
  # WSL y Linux sin escritorio no tienen servicio de keyring, y saml2aws falla al guardar la contraseña.
  [[ "$OS" == linux ]] && cmd+=(--disable-keychain)
  # mintty (la consola por defecto de Git Bash) no es una consola de Windows: sin winpty, saml2aws.exe
  # no puede leer la contraseña sin eco.
  if [[ "$OS" == windows && "${TERM_PROGRAM:-}" == mintty ]] && command -v winpty >/dev/null 2>&1; then
    cmd=(winpty "${cmd[@]}")
  fi
  "${cmd[@]}" || die "saml2aws login falló (mira el error justo encima)."

  local arn
  arn="$(aws sts get-caller-identity --profile "$PROFILE" --query Arn --output text)" ||
    die "El login terminó pero AWS no acepta las credenciales."
  ok "$arn"
}

main() {
  detect_platform
  install_saml2aws
  install_awscli
  configure
  login
  printf "\n${BOLD}Listo.${RST} La sesión dura 1 h; para renovarla, vuelve a ejecutar este script.\n"
  printf "Para usarla en esta terminal:  ${BOLD}export AWS_PROFILE=%s${RST}\n" "$PROFILE"
}

main "$@"
