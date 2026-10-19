# AWS CLI con usuario federado de Google (saml2aws)

Contexto para una futura spec. Se resolvió a mano el 2026-10-15 en el Mac de trabajo. Todavía no hay
nada en el repo salvo `brew "awscli"` en `packages/Brewfile`.

> **El repo es público.** Los identificadores de la empresa (los `idpid`/`spid` de Google, la cuenta de AWS,
> el nombre del rol y el email) **no se versionan**. Van en `~/.zshrc.local` (`*.local` está en `.gitignore`)
> o en el `~/.saml2aws` que genera la configuración. Aquí solo aparecen como placeholders.

## El problema

En el trabajo se entra a AWS desde Google Workspace: hay una app SAML en el menú de apps de Google que
federa directamente a un rol de IAM. Esa federación no tiene usuario de IAM ni portal
`…awsapps.com/start` (IAM Identity Center), así que no sirven ni `aws configure` (no hay access keys)
ni `aws configure sso`. Sin configurar nada, la CLI responde `NoCredentials: Unable to locate credentials`.

## Lo que funcionó

`saml2aws` con el proveedor `GoogleApps`. Hace el login de Google (contraseña + 2FA), recibe la aserción
SAML, llama a `sts:AssumeRoleWithSAML` y escribe credenciales temporales en un perfil de
`~/.aws/credentials`.

```bash
brew install saml2aws        # probado con 2.36.19; awscli 2.36.x

saml2aws configure \
  --idp-provider GoogleApps \
  --mfa Auto \
  --url "https://accounts.google.com/o/saml2/initsso?idpid=$SAML2AWS_GOOGLE_IDPID&spid=$SAML2AWS_GOOGLE_SPID&forceauthn=false" \
  --username "$SAML2AWS_USERNAME" \
  --profile "$SAML2AWS_PROFILE" \
  --session-duration 3600 \
  --skip-prompt

aws configure set region eu-west-1 --profile "$SAML2AWS_PROFILE"

saml2aws login               # interactivo: contraseña de Google, 2FA y elección de rol si hay varios
AWS_PROFILE="$SAML2AWS_PROFILE" aws sts get-caller-identity   # → arn:aws:sts::<cuenta>:assumed-role/<rol>/<email>
```

La URL `--url` es el enlace del icono de la app AWS en el menú de Google (botón derecho → copiar enlace).
Es la misma para todo el equipo.

### Ficheros que resultan

| Fichero | Contenido | ¿Versionable? |
|---|---|---|
| `~/.saml2aws` | INI `[default]`: `provider = GoogleApps`, `url`, `username`, `mfa = Auto`, `aws_profile`, `aws_session_duration = 3600`, `aws_urn = urn:amazon:webservices`. No guarda la contraseña. | **No**: lleva la URL con los ids y el email. Se genera con `saml2aws configure` desde variables de `~/.zshrc.local`. |
| `~/.aws/config` | `[profile <perfil>]` con `region = eu-west-1` | Podría versionarse, pero no aporta: lo crea `aws configure set`. |
| `~/.aws/credentials` | `[<perfil>]`: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`, `aws_security_token`, `x_principal_arn`, `x_security_token_expires` | **Nunca.** Son credenciales temporales (1 h). |

## Comportamientos a tener en cuenta

- **La sesión dura 1 h** (`--session-duration 3600`). Al caducar, la CLI vuelve a dar `NoCredentials` o
  `ExpiredToken`, y hay que repetir `saml2aws login`.
- **`AWS_PROFILE` no se hereda entre shells.** Una herramienta que lance comandos en otra shell (un agente,
  un script) tiene que recibir `AWS_PROFILE=<perfil>` o `--profile` de forma explícita.
- **`saml2aws login` es interactivo.** No se puede automatizar en `install.sh`; `install.sh` solo puede
  instalar y dejar configurado `~/.saml2aws`.
- **Errores transitorios:** `Could not connect to the endpoint URL "https://secretsmanager.eu-west-1…"` fue un
  fallo de red puntual que se resolvió reintentando.

## Decisión 2026-10-19: script standalone para el equipo

El objetivo pasa de configurar los dotfiles a tener un script que cualquiera del equipo pueda ejecutar
después de recibirlo por Slack: `tools/aws-google-login.sh`. Lo instala y lo configura todo, y solo pide
las autenticaciones (contraseña de Google, 2FA y, si hace falta, la de admin para la AWS CLI).

- **Plataformas:** macOS, Linux, WSL y Git Bash. No hay `.ps1`: en WSL el script es el de Linux, y en Git
  Bash detecta `MINGW*/MSYS*`, usa los binarios `.exe` y lanza `saml2aws` con `winpty` bajo mintty.
- **Ids fuera del repo:** `SAML_URL` y `AWS_PROFILE_NAME` están vacíos en la versión versionada. Se rellenan
  en la copia que se envía por Slack, y si llegan vacíos el script los pide. El email se pide siempre, con el
  de `~/.saml2aws` como valor por defecto.
- **Instalación:** `saml2aws` con Homebrew si existe; si no, el release fijado de GitHub con su sha256
  dentro del script. La AWS CLI con Homebrew, el `.pkg` (`sudo`), el zip oficial en `~/.local` (Linux, sin
  sudo) o `winget` (Windows, UAC).
- **Renovar la sesión** es volver a ejecutar el script: lo ya instalado y configurado se salta.
- **Sin probar todavía:** Git Bash, WSL y el login completo en una máquina limpia. Las instalaciones sí están
  probadas en macOS (release, HOME vacío) y en Debian bookworm arm64 y amd64.
- **Riesgo:** el proveedor `GoogleApps` hace scraping del login de Google. Si Google cambia el flujo
  (captcha, passkeys), deja de funcionar para todo el equipo a la vez.

Las ideas de abajo, para integrarlo en los dotfiles, quedan como opción aparte para mi máquina.

## Ideas para la spec (por decidir en /specs)

1. `packages/Brewfile`: `brew "saml2aws"`, más el check correspondiente en `test.sh`.
2. En `install.sh`, solo en macOS e idempotente: si están definidas `SAML2AWS_GOOGLE_IDPID`, `SAML2AWS_GOOGLE_SPID`,
   `SAML2AWS_USERNAME` y `SAML2AWS_PROFILE` (desde `~/.zshrc.local`) y no existe `~/.saml2aws`, ejecutar el
   `saml2aws configure … --skip-prompt` y el `aws configure set region`. Si faltan, avisar y seguir.
3. Una función de shell en `zsh/.config/zsh/` (por ejemplo `awslogin`) que haga `saml2aws login` y
   `export AWS_PROFILE=$SAML2AWS_PROFILE`, y que avise de cuánto le queda a la sesión leyendo
   `x_security_token_expires`. Necesita su check en `test.sh`.
4. Documentar en `README.md` qué variables van en `~/.zshrc.local` (ya existe la sección «Nada que sea secreto
   se versiona aquí»).
5. Linux/Debian: `saml2aws` no está en apt. Habría que bajarlo de GitHub Releases, como otros binarios del
   repo, o dejarlo fuera porque solo se usa en el Mac de trabajo.

### Variables de `~/.zshrc.local` (plantilla, sin valores reales)

```bash
export SAML2AWS_GOOGLE_IDPID="<idpid de la app SAML de Google>"
export SAML2AWS_GOOGLE_SPID="<spid de la app SAML de Google>"
export SAML2AWS_USERNAME="<tu email corporativo>"
export SAML2AWS_PROFILE="<nombre del perfil, p. ej. empresa-dev>"
```

Los valores reales ya están en el `~/.saml2aws` del Mac de trabajo (campo `url`). Se pueden copiar de ahí.

## Descartado

- **`aws configure sso`**: requiere IAM Identity Center, y aquí no lo hay.
- **`aws configure`** con access keys: no hay usuario de IAM.
- **`aws login`** (AWS CLI ≥ 2.32): no se llegó a probar; se fue directamente a `saml2aws`. Si se prueba y
  funciona con esta federación, sería la opción sin dependencias extra.
