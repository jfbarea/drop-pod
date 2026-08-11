---
name: worktree-cleanup
description: Limpia git worktrees y ramas locales muertas en los repos configurados. Borra solo lo demostrablemente integrado (PR MERGED en GitHub) y reporta el resto para decisión manual. La ejecuta a diario el LaunchAgent com.fran.worktree-cleanup; también se puede invocar a mano.
argument-hint: "[--dry-run]"
allowed-tools: Read, Write, Grep, Glob, Bash(git:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(du:*), Bash(lsof:*), Bash(date:*), Bash(mkdir:*), Bash(find:*), Bash(test:*), Bash(basename:*), Bash(dirname:*), Bash(jq:*), Bash(sed:*), Bash(awk:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(sort:*), Bash(uniq:*), Bash(wc:*), Bash(tr:*), Bash(cut:*), Bash(cat:*), Bash(printf:*), Bash(echo:*)
---

Limpieza de git worktrees y ramas locales en esta máquina.

Con `--dry-run` no borras **nada**: haces todo el inventario y la clasificación, y el informe
dice qué habrías borrado. Sin argumento, borras lo que las reglas permiten borrar.

## Repos a barrer

Formato `ruta|rama-de-integración`. Para ampliar, añade una línea.

```bash
REPOS=(
  "$HOME/src/revel/revel-app|development"
)
```

La rama de integración es la referencia contra la que se compara el trabajo salvable y la que
se usa para comprobar si un commit vive fuera de ella. Se usa siempre como `origin/<rama>`,
nunca la copia local (que puede estar desactualizada).

## Contrato de salida

Rutas fijas, con `HOY` = `date +%F`:

- Informe: `~/.local/state/worktree-cleanup/report-<HOY>.md`
- Red de seguridad: `~/.local/state/worktree-cleanup/deleted-branches-<HOY>.txt`

No uses `~/.claude/` para nada de esto: el harness protege ese directorio y la escritura se
deniega en silencio en una ejecución desatendida.

**Escribe siempre el informe, incluso cuando no haya nada que contar.** Es la señal de que la
ejecución llegó al final: el wrapper trata la ausencia del fichero como un fallo y avisa. Lo
que decide si te llega la notificación es la primera línea, no la existencia del fichero.

La **primera línea** del informe es siempre una de estas tres, seguida de una línea en blanco:

```
ESTADO: requiere-decision
ESTADO: informativo
ESTADO: silencioso
```

- `requiere-decision` — queda algo pendiente de que el usuario decida: worktree sucio, rama con
  PR cerrada sin mergear, cualquier cosa que no te atreviste a borrar.
- `informativo` — has borrado cosas y no hay nada pendiente.
- `silencioso` — no has borrado nada y no hay nada pendiente ni ningún aviso que merezca
  interrumpir al usuario. Con este estado el wrapper no notifica; el informe queda en disco.

Si no puedes escribir el informe, dilo explícitamente en tu respuesta final y no borres nada
más: sin informe no hay rastro de lo que hiciste.

## Procedimiento

Recorre los repos de `REPOS` uno a uno. Si una ruta no existe o no es un repo git, anótalo como
aviso y pasa al siguiente.

### 1. Inventario

`git -C <repo> worktree list --porcelain`. Usa `--porcelain`, no la salida corta: es la única
que parsea bien rutas con espacios y distingue `bare`, `detached` y `locked`.

Para cada worktree registra:

- rama (`branch refs/heads/<x>`) o si está en detached HEAD
- estado del árbol: `git -C <wt> status --porcelain=v1`, contando también untracked
- upstream: `git -C <wt> rev-parse --abbrev-ref '@{u}'` (falla si no hay)
- commits sin pushear: `git -C <wt> log --oneline @{u}..HEAD` cuando haya upstream
- tamaño en disco: `du -sh <wt>` y `du -sk <wt>` (el segundo para poder sumar KB)

Marca aparte, y trátalo como intocable, cualquier worktree que sea el **primero de la lista**
(el checkout principal), esté **`locked`**, o esté en **detached HEAD**.

### 2. Estado remoto fresco

`git -C <repo> fetch --prune origin` **antes de clasificar nada**. El `--prune` es lo que
revela qué ramas tienen el upstream borrado. Si el fetch falla (sin red, sin credenciales),
aborta ese repo entero: sin estado remoto fresco no puedes borrar nada con criterio. Anótalo
como aviso.

### 3. Clasificar el merge con `gh`, no con git

Para cada rama candidata:

```bash
gh pr list --repo <owner/repo> --state all --head <rama> --json number,state,mergedAt
```

`<owner/repo>` sale de `git -C <repo> remote get-url origin`.

Esto es **obligatorio**. El repo usa squash merge, así que `git branch --merged` da falsos
negativos y `git branch -d` se niega a borrar ramas que sí están integradas. La PR es la única
fuente de verdad sobre si algo está mergeado.

Clasificación por la respuesta:

- alguna PR con `state=MERGED` (o `mergedAt` no nulo) → **MERGED**
- solo PRs con `state=CLOSED` y `mergedAt` nulo → **CLOSED sin mergear**
- alguna PR con `state=OPEN` → **PR abierta**
- lista vacía → **sin PR**

Si `gh` falla (rate limit, sin auth), no borres nada de ese repo: anótalo como aviso.

### 4. Reglas de decisión

- **Worktree limpio + su PR MERGED** → borra worktree (`git -C <repo> worktree remove --force <wt>`)
  y rama (`git -C <repo> branch -D <rama>`). Automático, sin preguntar.
  Un `node_modules` untracked **no** cuenta como sucio: al decidir si un árbol está limpio,
  ignora los untracked que sean artefactos de build o dependencias (`node_modules/`, `build/`,
  `.gradle/`, `Pods/`, `ios/Pods/`, `.next/`, `dist/`, `vendor/`, `*.log`, `.DS_Store`).
  Cualquier otro untracked sí lo hace sucio.
- **Worktree con cambios sin commitear** → **NUNCA** lo toques automáticamente. Compara el
  working tree contra su rama de integración (`git -C <wt> diff origin/<integración> --stat` y
  el contenido de lo que salga) y en el informe distingue el trabajo real de lo rancio:
  reversiones de commits ya aplicados, ruido de Prettier, lockfiles regenerados.
  Los untracked hay que comprobarlos aparte: `git -C <wt> diff` contra una rama no los ve y
  los muestra como borrados. Para cada untracked relevante usa
  `git -C <wt> cat-file -e origin/<integración>:<fichero>` para saber si el fichero existe en
  la rama (entonces es un fichero que se sacó del índice) o es nuevo de verdad.
  Distingue también **índice** de **working tree** (`git -C <wt> status --porcelain=v1` da dos
  columnas): lo que está staged se captura con un solo `git commit`, y eso cambia lo fácil que
  es rescatar el trabajo.
  **No emitas veredictos de borrabilidad.** Puedes clasificar qué es trabajo real y qué es
  ruido, pero nunca escribas que un worktree sucio "se puede borrar sin pérdida" ni recomiendes
  borrarlo: presenta la evidencia (ficheros, commits, qué existe y qué no en la rama de
  integración) y deja la decisión al usuario. Un veredicto equivocado aquí cuesta trabajo
  irrecuperable, y esta clasificación no es reproducible entre ejecuciones.
- **Rama con upstream `[gone]` y PR MERGED** → bórrala (`git branch -D`).
- **Rama con upstream `[gone]` y PR CLOSED sin mergear** → **NUNCA** la borres. Si `origin` ya
  no la tiene, la rama local es la única copia de ese trabajo. Comprueba si tiene commits
  fuera de la rama de integración con
  `git -C <repo> log --oneline --no-merges origin/<integración>..<rama>` y repórtala con su
  lista de commits para que el usuario decida.
- **Rama sin upstream ninguno** (nunca pusheada) → fuera de alcance. Ni la mires: no la
  clasifiques, no la reportes, no la borres.
- **Rama con PR abierta** → puedes borrar la copia local si `origin` la conserva (upstream no
  `[gone]`) y el worktree está limpio, pero **dilo explícitamente en el informe**, con el
  número de PR.

Para distinguir `[gone]` de "sin upstream", una sola pasada:

```bash
git -C <repo> for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads
```

Upstream vacío → sin upstream (fuera de alcance). `[gone]` en el track → upstream borrado.

### 5. Red de seguridad antes de borrar

**Antes** de ejecutar cualquier borrado, vuelca a
`~/.local/state/worktree-cleanup/deleted-branches-<HOY>.txt` una línea por cada rama que vayas
a eliminar, con el SHA resuelto con `git -C <repo> rev-parse <rama>`:

```
<sha>  <repo>  <rama>  <ruta-worktree-o-vacío>
```

Así cualquier rama se resucita con `git branch <nombre> <sha>` mientras el objeto siga en el
reflog. Si no puedes escribir ese fichero, **no borres nada**.

Con `--dry-run` no escribas este fichero: en el informe basta con listar lo que se habría
borrado.

### 6. Cierre

`git -C <repo> worktree prune` y deja constancia del estado final: worktrees que quedan, ramas
que quedan, KB liberados (suma de los `du -sk` de lo borrado, conviértelo a un tamaño legible).

## Rails que no se pueden saltar

- **Nunca borres el checkout principal** (la primera entrada de `git worktree list`) ni el
  worktree desde el que se está ejecutando el propio job.
- **Nunca borres un worktree que tenga procesos vivos dentro.** Antes de cada
  `worktree remove`, comprueba `lsof -a -d cwd -w -- <wt>`; si hay algo, no lo borres y
  repórtalo como "en uso". Una sesión abierta ahí dentro no se queda sin suelo.
- **Nunca hagas `git push`** ni `git commit`. La limpieza solo borra worktrees y ramas locales:
  no reescribe historia ni publica nada. (Está además denegado en `settings.json` y por un hook
  `PreToolUse`; no intentes sortearlo.)
- **Nunca uses `git stash`.** El stack de stash es compartido entre worktrees del mismo repo y
  podrías reventar el trabajo de otra sesión.
- **Nunca `git clean`, `git reset --hard`, `git checkout -- .` ni `rm -rf` sobre un worktree.**
- **Nunca toques ramas fuera de los repos de `REPOS`.**
- Ante cualquier duda sobre si algo es trabajo salvable, **no borres y reporta**. El coste de
  dejar un worktree de más un día es cero; el de borrar un fix que nunca se mergeó es
  irrecuperable.

## Informe

En español, corto, markdown. Solo secciones que tengan contenido. Con `ESTADO: silencioso`
basta la cabecera, el título y una línea diciendo que no había nada que hacer. Estructura:

```
ESTADO: <requiere-decision|informativo|silencioso>

# Limpieza de worktrees — <YYYY-MM-DD>

## Borrado
- worktree `<ruta>` (rama `<rama>`, PR #<n> merged) — <tamaño>
- rama `<rama>` (upstream gone, PR #<n> merged)
**Espacio liberado:** <total>

## Requiere tu decisión
### Worktree sucio: `<ruta>` (rama `<rama>`) — <tamaño>
Trabajo real: <resumen de qué hay de verdad ahí>
Ruido: <lo rancio: reversiones ya aplicadas, Prettier, lockfiles>
### Rama con PR cerrada sin mergear: `<rama>` (PR #<n>)
Commits que solo viven aquí:
- <sha> <asunto>

## Avisos
- `origin/<integración>` está N commits por detrás / la copia local está desactualizada
- PR #<n> (`<rama>`) sigue abierta: su copia local se ha borrado, `origin` la conserva
- worktree `<ruta>` en uso por procesos vivos, no se toca

## Estado final
<repo>: N worktrees, N ramas locales
```

Si has escrito el informe, imprime también su ruta al final de tu respuesta. Nada de HTML: este
informe se manda por notificación y se lee en texto.
