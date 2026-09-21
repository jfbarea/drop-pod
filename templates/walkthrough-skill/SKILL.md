---
name: walkthrough
description: Genera un walkthrough en HTML de un diff completo, recorriéndolo hunk a hunk y explicando qué hace cada cambio, por qué se hizo así y cómo encaja con el resto. Úsala cuando pidan un walkthrough, un recorrido del diff, una explicación detallada de una PR, o documentar un cambio para poder defenderlo en una review. Sin argumento cubre el working tree más los commits locales frente a la rama base; con una PR (número, URL o rama), todo el diff de esa PR.
---

# Walkthrough en HTML

Produce **un fichero HTML autocontenido** que recorre un diff entero, diff a diff, con el nivel de detalle
que necesita quien va a defender ese código en una review como si lo hubiera escrito. Un resumen de alto
nivel por features o por ficheros **no vale**: es el criterio de calidad que decide si el documento está
bien hecho.

Un walkthrough **no es una code review**. Explica el código, no lo juzga. Si al leer el diff aparece algo
que huele mal, va en el apartado de observaciones y se dice en el chat; no se convierte el documento en un
informe de hallazgos.

## Instalación (para quien reciba este fichero)

Cópialo como `~/.claude/skills/walkthrough/SKILL.md` (solo para ti) o como
`.claude/skills/walkthrough/SKILL.md` dentro de un repo (para todo el equipo, versionado). Se invoca con
`/walkthrough`, con `/walkthrough <PR>`, o pidiéndolo en lenguaje natural.

## 1. Delimita el diff

**Con PR** (número, URL o rama): resuélvela con `gh pr view` y saca el diff completo con `gh pr diff`.
Recoge además el contexto:

```bash
gh pr view <pr> --json title,body,commits,baseRefName,headRefName,url,author,additions,deletions
gh pr diff <pr>
```

Si la URL es de otro repo, usa `gh -R <owner>/<repo>`. **Lee los ficheros completos en la versión head de
la PR**, no solo el diff: para explicar bien un hunk casi siempre hace falta más contexto del que da el
diff, y el working tree local puede no coincidir con el head.

```bash
gh api "repos/<owner>/<repo>/contents/<path>?ref=<headRef>" --jq .content | base64 -d
```

**Sin PR**: todo lo que ha cambiado, no solo el último cambio — commits locales frente a la rama base más
el working tree (`git diff <base>...HEAD`, `git diff HEAD`, o ambos). Si el ámbito es ambiguo, pregunta
antes de generar.

## 2. Dónde se escribe

Por defecto, `./walkthroughs/walkthrough-<slug>.html` dentro del repo (para una PR,
`walkthrough-pr-<número>-<slug>.html`). Crea el directorio si no existe y sugiere añadirlo a `.gitignore`
si no quieren versionar los documentos. Si el usuario indica otra ruta, manda la suya. Nombre de fichero en
kebab-case y descriptivo.

Al terminar, di la ruta del fichero generado.

## 3. Estructura del documento

En este orden, siempre igual. La consistencia es el objetivo: el mismo documento cada vez, no una variación
creativa.

1. **Cabecera** — `<header class="doc">` con eyebrow, título y una `<ul class="meta">` en grid:
   PR con enlace, autor, ramas base/head, estado, fecha, diff `+N / −M`, y la tarea si la hay.
2. **Resumen en una frase** — en un bloque destacado. Qué consigue el cambio en conjunto. Una frase de
   verdad, no un párrafo.
3. **Tally** — chips con el recuento: ficheros tocados, `+N / −M`, commits, y observaciones si las hay.
4. **Walkthrough** — el cuerpo del documento (ver abajo).
5. **Observaciones** — lo que haya salido al leer el diff, si algo ha salido. Cada una en un `<article
   id="fNN">` con badges separados de **severidad** y **confianza**, `fichero:línea` enlazado al blob del
   head, el hunk relevante, con qué entrada o estado concreto falla, y el fix propuesto en un bloque
   `.fix`. Si no hay ninguna, el apartado dice explícitamente que este documento no es una review y que no
   se ha juzgado el código.
6. **Alcance** — dos columnas: qué diff se cubrió / qué queda fuera.
7. **Footer** — fecha y de dónde salió el material (PR, rango de commits, working tree).

### El walkthrough (apartado 4)

Un `<details class="wt">` exterior **colapsado**, y dentro un `<details class="file">` por fichero, también
colapsado. Nunca un muro de mil líneas abierto de golpe.

- **Abre por lo que NO está en el diff** cuando hay algo central que no cambia (el hook que ya existía, el
  componente que solo se consume, el contrato que se respeta). Es lo primero que hace falta saber para leer
  el resto.
- **Tabla resumen** de todos los ficheros: ruta, `+N / −M`, y una línea de qué papel juega cada uno.
- **Agrupa en bandas `.groupbar`** por orden de lectura, no alfabético: componente compartido →
  consumidores → tests → infra/ruido. Cierra con una banda «Lectura de conjunto» de un párrafo.
- **Por fichero: el hunk primero, la prosa después.** El hunk en un `<pre>` con `+` verde, `-` rojo,
  contexto apagado y la cabecera `@@` en azul.
- **Exhaustividad.** Cada hunk se muestra seguido de su explicación: qué hace, por qué se hizo así, cómo
  encaja. Nada se omite por «menor»: renombres, imports, config, tests — todo lo que aparece en el diff se
  explica. Incluye el contexto que tendría el autor: decisiones tomadas, alternativas descartadas,
  invariantes que el cambio respeta. Apóyate en la descripción de la PR y en los mensajes de commit.
- **Separa el reflow del cambio real, siempre y de forma visible.** Un bloque `.reflow` que diga «Reflow, no
  cambio» y explique por qué es equivalente (precedencia explicitada, el formateador colapsando líneas,
  `{" "}` para conservar un espacio). Un diff de 16 líneas donde solo una es funcional tiene que leerse así.
- **Cuando N ficheros repiten un patrón, explica la receta una vez** y pon una tabla con lo que los
  diferencia. No N bloques calcados.
- **Enlaza a la observación** con un chip `.xref` («→ observación 03») apuntando a `#f03` desde cada punto
  del walkthrough donde aparezca. El walkthrough explica el código; la observación juzga.

## 4. Estilo

HTML autocontenido: CSS inline, sin dependencias externas más allá del `<link>` de Google Fonts (que
degrada a fuentes de sistema offline). Debe abrir con `file://` y verse bien también embebido en un iframe
estrecho: layout responsive, sin frame-busting, sin depender de `window.top` ni de popups.

**Dark mode fijo.** Paleta dark hard-coded en `:root`, sin `@media (prefers-color-scheme)`, sin toggle, sin
fallback claro. Para cambiar la identidad visual, cambia estos tokens y nada más:

```css
:root{
  --paper:#191815;      /* fondo base */
  --surface:#211F1B;    /* paneles, cabeceras */
  --surface-2:#262420;  /* inputs, hovers */
  --ink:#ECEAE2;        /* texto principal */
  --muted:#928D82;      /* texto secundario */
  --faint:#5C584F;      /* texto terciario, separadores suaves */
  --line:#332F29;       /* bordes */
  --accent:#5FA892;     /* acento */
  --accent-soft:#5fa8921f;
  --shadow:0 1px 2px rgba(0,0,0,.2),0 12px 28px rgba(0,0,0,.28);
  --radius:14px;
}
```

**Tipografía.** Titulares `"Fraunces",serif`; texto corrido `"Newsreader",Georgia,serif`; metadatos, código
y etiquetas `"JetBrains Mono",monospace`. Siempre con fallback de sistema en cada `font-family`.

**Estados semánticos** (crítico, warning, info): rojo/amarillo/azul saturados que contrasten sobre
`--paper`. El acento se queda como color de marca y el resto de la UI en los tokens de arriba.

**Diagramas en SVG inline, nunca en ASCII art.** Cualquier flujo, arquitectura, secuencia, árbol o grafo se
dibuja como SVG: `--ink` para trazos y texto, `--accent` para resaltados, `--line`/`--faint` para
conectores, `--surface`/`--surface-2` para rellenos de nodos, tipografía del documento en las etiquetas, y
`viewBox` + ancho `100%` para que escale.

**Clases, para que el documento salga igual cada vez:** `.wt` / `.file` (desplegables), `.groupbar` (banda
de grupo, mono en `--accent`), `.reflow` (aviso con barra lateral `--faint`), `.xref` (chip amarillo),
`.finding` + `.sev-*` (borde izquierdo por severidad), `.badge` + `.b-*` (severidad/confianza), `.fix`
(bloque verde), `.panel` (alcance), `.tblwrap` (toda tabla scrollea dentro de su caja; el body nunca en
horizontal).

### Impresión a PDF

El documento se exporta imprimiendo desde el navegador, así que lleva su propia hoja de impresión:

- Tipografía en `pt` legibles en A4: cuerpo ~11pt, `h1` ~20pt, `h2` ~15pt, `h3` ~13pt.
- `@page{size:A4;margin:14mm}`, y el fondo `--paper` puesto en el **root (`html`)** dentro de
  `@media print` — es lo que hace que el navegador pinte también el margen y no queden franjas blancas
  alrededor del diseño oscuro.
- `break-inside:avoid` en tarjetas, `pre`, tablas, figuras y SVG; `break-after:avoid` en titulares.
- `print-color-adjust:exact` (con prefijo `-webkit-`) para conservar la paleta sin depender de que se
  active «Background graphics» en el diálogo de impresión.
- Oculta los botones «copiar» y los marcadores `▸` en `@media print`.

### Mecánica de los desplegables

- Un `<details>` cerrado **no se abre con CSS al imprimir**. Añade un script inline que en `beforeprint`
  los abra guardando su estado y en `afterprint` lo restaure. Sin eso, el PDF sale sin walkthrough.
- Marcadores `▸` que rotan al abrir, en `--accent`.
- Si pones botones de copiar, que usen `navigator.clipboard` y **caigan a seleccionar el rango** cuando el
  portapapeles esté bloqueado (pasa al servir el HTML dentro de un iframe).

## 5. Verificaciones antes de dar el fichero por bueno

- **Cada `fichero:línea` cae donde dices.** Léelo en el head de la PR y cuenta; no lo deduzcas del diff.
- **Los enlaces a blobs apuntan al head de la PR**, no a la rama base ni a `main`.
- **El HTML está balanceado.** Válidalo con un parser antes de cerrar: cero errores, nada sin cerrar.
- **Todos los ficheros del diff aparecen** en la tabla resumen y tienen su `<details>`.

## Idioma

Escribe el documento en el idioma en el que te esté hablando el usuario.
