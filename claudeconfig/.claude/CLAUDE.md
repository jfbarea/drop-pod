# Preferencias personales — Fran

Este fichero contiene preferencias globales del usuario. Se carga **en toda sesión de Claude Code, en cualquier repositorio**.

## Tono

- Tono neutro, profesional y directo. Sin persona ni roleplay.
- Nada de metáforas temáticas, apelativos ni personajes. La voz no adorna: va al contenido técnico.
- Refiérete a los subagentes por su slug técnico (`architect`, `builder`, `reviewer`, `debugger`, `auditor`).

## Output en HTML

Cuando generes HTML como **output principal** para el usuario (artefactos de `/research`, reviews HTML, audits HTML, mockups, dashboards, prototipos):

- **Dark mode hard-coded.** Paleta dark fija en `:root` desde el principio.
- **No** uses `@media (prefers-color-scheme: dark)` — eso depende del SO; el usuario quiere dark siempre.
- **No** ofrezcas light mode como fallback ni añadas toggle.
- **Estilo del scriptorium (estilo de casa).** Todo HTML que generes adopta la identidad visual del visor scriptorium: paleta "papel oscuro" cálida con un único acento verde apagado y tipografía serif editorial. Copia estos tokens en `:root`:
  ```css
  :root{
    --paper:#191815;      /* fondo base */
    --surface:#211F1B;    /* paneles, cabeceras */
    --surface-2:#262420;  /* inputs, hovers */
    --ink:#ECEAE2;        /* texto principal */
    --muted:#928D82;      /* texto secundario */
    --faint:#5C584F;      /* texto terciario, separadores suaves */
    --line:#332F29;       /* bordes */
    --accent:#5FA892;     /* acento (verde apagado) */
    --accent-soft:#5fa8921f;
    --shadow:0 1px 2px rgba(0,0,0,.2),0 12px 28px rgba(0,0,0,.28);
    --radius:14px;
  }
  ```
- **Tipografía del scriptorium.** Titulares con `"Fraunces",serif`; texto corrido con `"Newsreader",Georgia,serif`; metadatos, código y etiquetas con `"JetBrains Mono",monospace`. Carga las fuentes con el `<link>` de Google Fonts (`Fraunces`, `Newsreader`, `JetBrains Mono`) **con fallback de sistema** en cada `font-family`, para que offline degrade a serif/monospace sin romperse.
- Para **estados semánticos** (crítico, warning, info en reviews/audits) añade rojo/amarillo/azul saturados que contrasten sobre el `--paper`, pero deja el verde `--accent` como color de marca y mantén el resto de la UI en los tokens de arriba.
- **Esquemas y diagramas en SVG, nunca en texto plano.** Cualquier diagrama (flujos, arquitecturas, secuencias, árboles, grafos, relaciones) se dibuja como SVG inline, no como ASCII art ni bloques de texto preformateado. El SVG usa los tokens del scriptorium (`--ink` para trazos y texto, `--accent` para resaltados, `--line`/`--faint` para conectores y bordes, `--surface`/`--surface-2` para rellenos de nodos), tipografía del scriptorium en las etiquetas, y `viewBox` + ancho `100%` para que escale dentro del iframe estrecho. Autocontenido como el resto del HTML.
- **Bloque `@media print` obligatorio (PDF guapo).** El scriptorium exporta cada página a PDF imprimiendo desde el navegador, así que toda página lleva su propia hoja de impresión para que el PDF salga maquetado, no como un volcado de pantalla:
  - Tipografía en `pt` legibles en A4: cuerpo ~11pt y titulares jerarquizados (`h1` ~20pt, `h2` ~15pt, `h3` ~13pt), no los tamaños grandes de pantalla.
  - `@page{size:A4;margin:14mm}` para que los saltos tengan respiro, y el fondo `--paper` puesto en el **root (`html`)** dentro de `@media print`, que es lo que hace que el navegador pinte también el margen de la página y no queden franjas blancas alrededor del diseño oscuro.
  - `break-inside:avoid` en bloques que no deben partirse (tarjetas, `pre`, tablas, figuras, SVG) y `break-after:avoid` en titulares para que no queden huérfanos. Como conoces las clases de tu propia página, márcalas aquí (la exportación genérica del scriptorium solo alcanza selectores comunes).
  - `print-color-adjust:exact` (con prefijo `-webkit-`) para conservar la paleta sin depender de que se active "Background graphics" en el diálogo.
- HTML autocontenido: CSS inline, sin dependencias externas más allá del `<link>` de fuentes (que degrada offline), abre con `file://`.
- **Ubicación.** Si el HTML se genera desde un repositorio, créalo en `~/src/html/<repo-name>/`, donde `<repo-name>` es el nombre del directorio raíz del repo (el basename de `git rev-parse --show-toplevel`). Ejemplo: desde un repo `revel-app` → `~/src/html/revel-app/`. Crea el directorio si no existe. No dejes el HTML dentro del propio repo salvo que el usuario lo pida explícitamente.
- **Rotación a `archive/` (obligatoria al escribir).** El scriptorium solo se nutre cuando el usuario te pide generar un HTML en `~/src/html/<repo-name>/`. Cada vez que vayas a crear uno, **antes de escribirlo** rota esa misma carpeta por antigüedad (mtime) en cuatro niveles:
  - Nivel superior de `~/src/html/<repo-name>/` → solo los ficheros de **hoy**.
  - `archive/Yesterday/` → los de **ayer**.
  - `archive/Last Week/` → los de la **última semana** (≤7 días), excepto los de hoy y ayer.
  - `archive/Long Time/` → todo lo de **más de 7 días**.
  Reglas:
  - Orden, de más viejo a más nuevo: (1) a `Long Time` lo de >7 días esté donde esté (nivel superior, sueltos en `archive/`, `Yesterday` o `Last Week`); (2) a `Last Week` lo anterior a ayer que quede en nivel superior, `archive/` o `Yesterday`; (3) a `Yesterday` lo de ayer que quede en nivel superior o `archive/`. Crea los tres subdirectorios si no existen. Con estos pasos, lo que envejece va cayendo de nivel solo y los sueltos legacy de `archive/` migran también.
  - Solo esos niveles (no desciendas dentro de `Long Time`, no toques otras carpetas de repos).
  - **No** muevas: los subdirectorios de `archive/`, `index.html` (es la landing que sirve Caddy en esa carpeta), ni basura del sistema (`.DS_Store`, `.localized`).
  - El fichero nuevo que vas a crear se queda en el nivel superior (es de hoy). El criterio es el mtime, así que regenerar un doc lo devuelve a la carpeta principal.
  - Ante colisión de nombre en el destino, no sobrescribas: añade sufijo (p. ej. `.archived-<epoch>`).
  - Comando de referencia (ejecútalo para el `<repo-name>` en el que estés escribiendo):
    ```bash
    D=~/src/html/<repo-name>; A="$D/archive"; Y="$A/Yesterday"; LW="$A/Last Week"; LT="$A/Long Time"
    mkdir -p "$Y" "$LW" "$LT"
    MV='d="$1"; shift; for f; do t="$d/$(basename "$f")"; [ -e "$t" ] && t="$t.archived-$(date +%s)"; mv "$f" "$t"; done'
    EX=(! -name index.html ! -name '.DS_Store' ! -name '.localized')
    find "$D" "$A" "$Y" "$LW" -mindepth 1 -maxdepth 1 -type f "${EX[@]}" -mtime +7 \
      -exec sh -c "$MV" _ "$LT" {} +
    find "$D" "$A" "$Y" -mindepth 1 -maxdepth 1 -type f "${EX[@]}" ! -newermt "$(date -v-1d +%F)" \
      -exec sh -c "$MV" _ "$LW" {} +
    find "$D" "$A" -mindepth 1 -maxdepth 1 -type f "${EX[@]}" ! -newermt "$(date +%F)" \
      -exec sh -c "$MV" _ "$Y" {} +
    ```
- **Compatible con el scriptorium.** Todo HTML que generes en `~/src/html/` lo sirve y cataloga el servidor local "scriptorium" (Caddy), que lista el árbol y **previsualiza los `.html` dentro de un iframe** en su panel lector. Para que encaje:
  - Extensión `.html` y nombre de fichero descriptivo en kebab-case (el catálogo filtra por extensión y abre inline solo los `.html`).
  - Debe verse bien **embebido en un iframe estrecho**: layout responsive, nada de frame-busting ni `target="_top"`, sin asumir que es la ventana top-level (no dependas de `window.top`, popups, ni de la URL de la barra).
  - El dark-mode fijo y el ser autocontenido (reglas de arriba) ya lo hacen consistente con el visor; mantenlos.

## Walkthroughs y code reviews en el scriptorium

Aplica **siempre que pida un walkthrough o una review** en HTML, venga por `/walkthrough`,
`/code-review-scriptorium` o a pelo. Hereda todas las reglas de `## Output en HTML` (tokens, dark fijo,
tipografía, SVG, `@media print`, rotación a `archive/`, iframe estrecho) y añade la estructura, que no es
negociable: quiero el mismo documento cada vez, no una variación creativa.

### Esqueleto, en este orden

1. **Cabecera** — `<header class="doc">` con eyebrow, título, y una `<ul class="meta">` en grid de
   metadatos (PR con enlace, autor, ramas, estado, fecha, diff `+N / −M`, tarea, y si hubo `--fix`/`--comment`).
2. **Veredicto en una frase**, en un bloque coloreado por gravedad. Una frase de verdad, no un párrafo.
3. **Tally** — chips con el recuento: hallazgos, cuántos por severidad, descartados, comentarios propuestos.
4. **Walkthrough** — desplegable (ver abajo).
5. **Hallazgos** — uno por `<article>`, de más grave a menos.
6. **Alcance de la review** — dos columnas: qué se cubrió / qué queda fuera.
7. **Comprobado y descartado** — tabla de lo que se miró y no sobrevivió. Sin esto el informe se lee como
   «está todo bien» cuando dice «esto es lo que se miró».
8. **Footer** con fecha y de dónde salieron los hallazgos.

### El walkthrough

Un `<details class="wt">` exterior **colapsado**, y dentro un `<details class="file">` por fichero, también
colapsado. Nunca un muro de 1.000 líneas abierto.

- **Abre por lo que NO está en el diff** cuando hay algo central que no cambia (el hook que ya existía, el
  componente que solo se consume). Es lo primero que hay que saber para leer el resto.
- **Tabla resumen** de todos los ficheros: ruta, `+N / −M`, y una línea de qué papel juega cada uno.
- **Agrupa en bandas `.groupbar`** por orden de lectura, no alfabético: componente compartido → consumidores
  → tests → infra/ruido. Cierra con una banda «Lectura de conjunto» de un párrafo.
- **Por fichero: el hunk primero, la prosa después.** El hunk en un `<pre>` con `+` verde, `-` rojo,
  contexto apagado y la cabecera `@@` en azul.
- **Separa el reflow del cambio real, siempre y de forma visible.** Un bloque `.reflow` que diga «Reflow, no
  cambio» y explique por qué es equivalente (precedencia explicitada, Prettier colapsando líneas, `{" "}`
  para conservar un espacio). Un diff de 16 líneas donde solo una es funcional tiene que leerse así.
- **Cuando N ficheros repiten un patrón, explica la receta una vez** y pon una tabla con lo que los
  diferencia. No N bloques calcados.
- **Enlaza al hallazgo** con un chip `.xref` («→ hallazgo 03») que apunte a `#f03` desde cada punto del
  walkthrough donde aparezca. El walkthrough explica el código; el hallazgo juzga.

### Los hallazgos

Cada uno `<article id="fNN">`, con: badges de **severidad y confianza** separados, `fichero:línea` enlazado
al blob **del head de la PR**, el hunk relevante, con qué entrada o estado concreto falla, y el fix
propuesto en un bloque `.fix`.

Si la review la hizo un motor (el built-in de Anthropic, otro agente), el HTML es **acta**: no añadas
hallazgos, severidades ni conclusiones que no diera. Si crees que le falta algo, dímelo en el chat.

### Comentario propuesto para la PR

**Cada hallazgo lleva su comentario listo para pegar**, en un bloque `.prcomment` con tres partes: el
anclaje, el texto en markdown, y un botón «copiar». Si el hallazgo toca dos ficheros, dos comentarios.

- **Anclaje explícito**: `fichero · línea · lado derecho del diff · hunk @@ …`.
- **Sucinto, o no se lee.** Presupuesto: el más largo ~130 palabras, y la mayoría en 3-5 líneas. Fuera
  preámbulos («el detalle es que…»), rutas que el anclaje ya da, y listas de viñetas que caben en una frase
  con comas. Dentro, intactos, los datos verificables que lo hacen accionable: `fichero:línea`, nombres de
  constantes y de variables reales, el número concreto.
- **Bloques ` ```suggestion ` solo si compilan.** Usa los nombres de variable **leídos del head**, no los
  que parezcan lógicos. Nunca propongas un suggestion que rompa un test o que necesite tocar una línea
  fuera del hunk — eso va en prosa.
- **No publiques nada** sin `--comment` explícito. El informe dice que están redactados y sin publicar.
- Comentarios y PRs en español, como el resto.

### Verificaciones obligatorias antes de dar el fichero por bueno

- **Lee los ficheros en el head de la PR, no solo el diff**, y confirma que cada `fichero:línea` cae donde
  dices. `gh api "repos/<r>/contents/<path>?ref=<branch>"` y a contar.
- **Confirma que cada anclaje cae dentro de un hunk.** GitHub no acepta un comentario inline fuera del
  diff, y un anclaje muerto convierte el informe en trabajo tirado.
- **Valida el balanceo de etiquetas** del HTML con un parser antes de cerrar. Cero errores, nada sin cerrar.

### Mecánica del desplegable

- Un `<details>` cerrado **no se abre con CSS al imprimir**. Añade un script inline que en `beforeprint`
  los abra guardando su estado y en `afterprint` lo restaure. Sin eso el PDF sale sin walkthrough.
- Oculta los botones «copiar» en `@media print`.
- El botón copia con `navigator.clipboard` y **cae a seleccionar el rango** si el portapapeles está
  bloqueado — el scriptorium sirve el HTML dentro de un iframe.
- Marcadores `▸` que rotan al abrir, en el verde `--accent`. En `@media print`, sin marcador.

### Componentes visuales

Sobre los tokens de `## Output en HTML`, con estos nombres de clase para que el documento salga igual cada
vez: `.wt` / `.file` (desplegables), `.groupbar` (banda de grupo, mono en `--accent`), `.reflow` (aviso con
barra lateral `--faint`), `.xref` (chip amarillo al hallazgo), `.finding` + `.sev-*` (borde izquierdo por
severidad), `.badge` + `.b-*` (severidad/confianza), `.fix` (bloque verde), `.prcomment` (borde izquierdo
azul) con `.anchor` + `pre.cmt` + `button.copy`, `.panel` (alcance y descartados), `.tblwrap` (toda tabla
scrollea dentro de su caja, el body nunca en horizontal).

## Commits y trabajo

- **Commitea al terminar la tarea, sin esperar a que te lo pidan.** Cuando acabes un trabajo y el working tree tenga cambios, agrúpalos en commits atómicos y commitéalos con la misma calidad que `/commit`: un cambio lógico por commit, mensaje `tipo(scope): resumen` en imperativo, el porqué en el cuerpo cuando no sea obvio. No dejes cambios colgando en el working tree como estado final.
- **Salvo en rama protegida.** Comprueba la rama antes de commitear: si HEAD está en `main`, `master`, `dev`, `develop`, `development` o `alpha` (o variantes en mayúsculas), **no commitees**. Deja los cambios en el working tree, dilo al terminar y ofrece crear rama o commitear ahí si el usuario lo pide. Es la misma lista de ramas que veta el push.
- Excepciones: si el usuario pide explícitamente que no commitees, o que deje los cambios en el working tree para revisarlos, respétalo. Y si el trabajo queda a medias (tests rojos, algo sin terminar), no lo commitees: dilo y deja el árbol como está.
- `/commit` sigue existiendo para commitear lo que ya estuviera pendiente de antes.
- En todo repositorio, sigue las reglas de commits atómicos si están descritas en el `CLAUDE.md` del proyecto.
- No saltes hooks (`--no-verify`, `--no-gpg-sign`) salvo petición explícita.
- Prefiere crear commits nuevos antes que `--amend` cuando algo falla.
- **Ramas protegidas: `git push` prohibido.** Nunca pushees a `main`, `master`, `dev`, `develop`, `development` ni `alpha` (ni variantes en mayúsculas). Tampoco `--all` ni `--mirror`, que arrastran esas ramas. El push a ramas protegidas lo hace el usuario a mano. Hay un hook (`~/.claude/hooks/block-protected-push.sh`) que lo bloquea; no intentes sortearlo.
- **En cualquier otra rama, el push está permitido** cuando el usuario lo pida (explícitamente o como parte de un flujo que lo requiera, p. ej. abrir una PR). No hace falta confirmación extra. Sigue sin usarse `--no-verify`.
- Si el hook no puede determinar a qué rama apunta el push (variables, subshells, HEAD desacoplado), lo bloquea por precaución: usa un refspec explícito (`git push origin mi-rama`).
- **Pull requests en español.** Cuando crees una PR, todo su texto (título, descripción, comentarios, checklist…) va en español.

## Cómo se actualiza este fichero

- Vive versionado en el repo de dotfiles del usuario: `claudeconfig/.claude/CLAUDE.md`.
- Está symlinkado a `~/.claude/CLAUDE.md` por stow.
- Para añadir preferencias durables nuevas, edita el fichero del dotfile y `git commit`. El test del proyecto verifica que el symlink existe.
