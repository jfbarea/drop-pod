# Review — hito 2: catalog-delete-button

## Veredicto: CHANGES_REQUESTED

## Alcance de esta revisión

`git diff HEAD -- macos/scriptorium-browse.html` mezcla el trabajo de este hito
con una refactorización previa no relacionada (`human`/`ext`/`tag`/`bytes`
retirados, `label`/`fetchTitle`/`title` añadidos, orden de sort por título) que
las notas del builder documentan explícitamente como ya presente antes de
empezar este hito y no tocada por él. La tomo en su palabra para lo que no es
de borrado (no es objeto de esta review), y centro el análisis crítico en lo que
sí es de este hito: icono `TRASH`, CSS `.entry .meta .trash*`, `showEmptyReader`,
`wireTrash`, el campo `parent: node` en `loadChildren`, y sus puntos de
integración en `entryEl`/`openDoc`.

## Bloqueantes

1. **Un doble-click rápido y literal sobre el icono de papelera ejecuta un
   borrado real, sin que el usuario tenga ninguna oportunidad de leer ni
   registrar el paso de confirmación.** `macos/scriptorium-browse.html:449-459`.
   El primer click añade la clase `confirm` de forma **síncrona** (no hay
   ningún `await` antes de ese `return`); si el segundo `click` llega antes de
   que el navegador o el usuario lleguen a pintar/leer nada (un doble-click de
   ratón/trackpad dispara dos eventos `click` separados en sucesión inmediata,
   sin ninguna semántica especial que los coalesce), el segundo evento entra
   directamente en la rama `else` (ya tiene `confirm`) y ejecuta el `POST
   /-/delete` de verdad.

   Verificado **no de forma especulativa sino ejecutando el código real**
   extraído del fichero, en Chrome headless con DOM real (`document.createElement`,
   `classList`, `dispatchEvent` reales) y `fetch` mockeado, virtual-time-budget
   para los timers: dos `dispatchEvent(new MouseEvent('click'))` consecutivos
   sobre el mismo botón, sin esperar nada entre medias, resultan en
   `scenarioA_deleteCallsAfterRapidDoubleClick: 1` y
   `scenarioA_nodeStillInParentAfter: false` — el fichero queda borrado tras
   dos clicks pegados, exactamente el escenario de "click accidental" que el
   propio PLAN dice querer evitar ("Confirmación en dos pasos... para evitar
   borrados por click accidental"). Un doble-click es, si acaso, el patrón *más*
   habitual de click accidental (rebote de trackpad/ratón, hábito de doble-click
   de otras apps de ficheros), así que el mecanismo de dos pasos no cumple su
   propio objetivo declarado frente a esa entrada concreta.

   Sugerencia de arreglo, mínima y de bajo riesgo: exigir un tiempo mínimo de
   permanencia en estado `confirm` antes de que el segundo click cuente como
   ejecución — p. ej. guardar `armedAt = Date.now()` al entrar en `confirm` y, en
   la rama de "ya está en confirm", ignorar el click (sin resetear el timer de
   3s) si `Date.now() - armedAt < 350`. No hace falta AbortController ni
   reestructurar el resto del flujo.

## Sugerencias

1. **Mensaje de error crudo del navegador para fallos de red, inconsistente con
   `doShare`.** `macos/scriptorium-browse.html:477-483`: `btn.textContent =
   err.message || 'error'` no distingue `TypeError` (bridge caído/red rota, el
   mismo caso que `doShare` especializa como "no se pudo conectar con el
   bridge") de un `Error` con el mensaje del backend (ya en español, p. ej. "no
   existe"). Confirmado contra el bridge real: los mensajes del backend (`{"error":
   "no existe"}`, `{"error": "no se pueden borrar directorios"}`) ya están en
   español y caben bien en el botón, pero un bridge caído produciría el texto
   nativo del navegador (típicamente "Failed to fetch" en Chrome), en inglés,
   rompiendo el tono en español del resto del visor. El propio builder lo señaló
   para mi criterio: recomiendo alinearlo con el patrón de `doShare` (`e
   instanceof TypeError` → texto fijo en español) por consistencia, aunque no
   bloqueo la aprobación solo por esto — el criterio de aceptación ("con el
   bridge parado → error visible y visor usable") se cumple igual con el texto
   crudo.
2. **`aria-label` estático oculta el cambio de estado a un lector de pantalla.**
   `macos/scriptorium-browse.html:422`: `aria-label="Borrar ${label(node)}"` no
   cambia entre los estados `idle`/`confirm`/`borrando…`/`error` (a diferencia
   del `textContent` visual, que sí cambia) — y `aria-label`, cuando está
   presente, **sustituye** por completo al contenido de texto en el nombre
   accesible calculado del botón. Un usuario de lector de pantalla oiría
   "Borrar doc.html, botón" tanto en el primer click (confirmación) como en el
   segundo (ejecución), sin ninguna pista de que el primero solo pide
   confirmar — el mecanismo de dos pasos, pensado explícitamente para evitar
   acciones accidentales, queda mudo por este canal. Es una herramienta personal
   de un solo usuario y el PLAN solo pedía "accesible por teclado" (que sí se
   cumple: Tab llega al botón, Enter/Espacio disparan el mismo `onclick`), así
   que no lo bloqueo, pero lo documento como riesgo real si algún día se usa
   con lector de pantalla.
3. **`<button>` anidado dentro de `<a>`**: contenido interactivo dentro de
   contenido interactivo, inválido según el content model estricto de HTML5.
   Verificado de forma independiente (no solo confiando en la afirmación del
   builder) con Chrome real en headless: el parser NO reubica el `<button>`
   fuera del `<a>` (a diferencia de, p. ej., `<button>` dentro de `<button>`,
   que sí tiene una regla de auto-cierre en el algoritmo de parseo — `<a>` no
   está en ese conjunto de reglas para contenido `<button>` anidado), el DOM
   resultante anida tal cual se escribió, y `stopPropagation()` en el click del
   botón impide de verdad que se dispare el `onclick` del `<a>` padre (probado
   con `dispatchEvent` real, `bubbles:true`). Funcionalmente correcto y sin
   riesgo de que un cambio de motor de renderizado lo rompa (no depende de un
   comportamiento "permisivo" ambiguo, sino de que la regla de reparenting
   específica de HTML5 simplemente no aplica a este par de etiquetas). Aceptable
   tal cual para esta herramienta personal; lo señalo solo como deuda técnica
   documentada, no bloqueante.

## Riesgos

Ninguno nuevo de seguridad — el endpoint ya se validó exhaustivamente en la
review del hito 1 (`plan/scriptorium-delete/reviews/hito-1-delete-endpoint.md`,
APPROVED en ronda 2). Este hito no toca el bridge ni el Caddyfile.

## Verificación realizada

- Lectura de `plan/scriptorium-delete/PLAN.md` (hitos 1 y 2), `_state.json`
  completo (incluida la review ya aprobada del hito 1) y el diff de
  `macos/scriptorium-browse.html`.
- `node --check` sobre el `<script>` extraído (placeholders Go-template
  sustituidos) → sin errores de sintaxis.
- **Anidamiento `<a><button>`** verificado con Chrome real en headless
  (`--headless=new --dump-dom`), DOM real, montando el CSS/SVG reales del
  fichero: `buttonIsDirectChildOfA: true`, `nestedOk: true`,
  `openDocCalledAfterTrashClick: false` (el click en la papelera no abre el
  doc), `openDocCalledAfterRowClick: true` (el resto de la fila sigue abriendo
  el doc con normalidad) — confirmado con `dispatchEvent` real, no simulado a
  mano.
- **Los 5 flujos asíncronos pedidos**, verificados ejecutando el código real
  extraído del fichero (no reescrito) en Chrome headless con DOM real, `fetch`
  mockeado y `--virtual-time-budget` para resolver los timers de 3s/4s sin
  esperar en tiempo real:
  - Doble-click rápido → **Bloqueante 1** (arriba).
  - Confirmar justo cuando el timeout de 3s acaba de expirar: sin condición de
    carrera real — el single-thread de JS serializa el callback del
    `setTimeout` y el handler del click, nunca se solapan a medio ejecutar.
    Confirmado con dos casos exactos: click a los 2900ms de la confirmación
    (`scenarioB1_deleteFiredBeforeExpiry: true`, ejecuta el borrado, correcto)
    y a los 3100ms (`scenarioB2_classAfterExpiry: ["trash"]` — `idle()` ya
    limpió la clase antes de que llegara el click —
    `scenarioB2_deleteFiredAfterExpiryPlusOneClick: false`, el segundo click
    reinicia un ciclo de confirmación nuevo en vez de ejecutar, correcto).
  - Borrar mientras hay búsqueda activa: confirmado que el estado `confirm` NO
    sobrevive a un re-render (`renderSearch()` reconstruye `entryEl` desde cero,
    `scenarioC_oldBtnStillInDocument: false`, `scenarioC_newBtnClassIsClean:
    ["trash"]`) y que el botón nuevo para el mismo nodo se comporta como un
    primer click limpio (`scenarioC_firstClickOnNewBtnTriggeredDelete: false`),
    no como una ejecución fantasma heredada del estado viejo. El `timer` del
    botón viejo (huérfano, en un nodo ya desconectado del documento) no
    produce ningún efecto visible cuando termina de expirar — mutar un nodo
    DOM detached es inocuo.
  - Borrar el doc abierto mientras su `/-/share` está en vuelo: confirmado con
    un harness que abre `doc1.html`, dispara `doShare` (deja el `fetch` a
    `/-/share` sin resolver, simulando los 30-180s reales de publicación), y
    borra `doc1.html` desde su fila del catálogo. Resultado:
    `activeAbsAfterDelete: null`, `readerShowsEmptyAfterDelete: true`,
    `shareWrapGoneAfterDelete: true`, sin excepción no capturada
    (`unhandledrejection` vigilado explícitamente) cuando la petición vieja de
    `/-/share` finalmente resuelve con éxito real — `shareWrapFor` encuentra
    `document.getElementById('share')` como `null` (el `showEmptyReader()` ya
    sustituyó por completo el `readerEl.innerHTML`) y `doShare` hace `return`
    limpio en su continuación, sin pintar nada sobre un lector que ya no
    corresponde a ese doc. Mismo mecanismo ya verificado como seguro en las
    reviews de `scriptorium-share` (hito 3) para el caso análogo de cambiar de
    doc con una publicación en vuelo.
  - Borrar el doc abierto con el iframe cargado: cubierto por el mismo
    escenario anterior — `showEmptyReader()` sustituye `readerEl.innerHTML`
    entero, lo que descarta el `<iframe>` (navegación en curso cancelada por el
    propio navegador al desconectar el elemento, comportamiento estándar, sin
    referencias colgantes en el código a ese `frame`).
- **`node.parent` en `loadChildren`**: no hay `JSON.stringify` de nodos del
  árbol en ningún punto del fichero (grep confirmado; los únicos usos de
  `JSON.stringify` son sobre literales `{path: node.abs}` en `doShare`/
  `wireTrash`, nunca sobre el nodo completo), así que el ciclo
  padre↔hijos nunca llega a esa función. Un ciclo padre/hijo en un árbol es una
  estructura de datos legítima y no supone fuga de memoria en un motor con
  recolector de ciclos (V8 y el resto de motores modernos la manejan sin
  problema; solo sería un problema en un GC de conteo de referencias sin
  detección de ciclos, no aplicable aquí). Ninguna función recorre el árbol
  vía `.parent` (todas usan `.children`), así que no hay riesgo de bucle
  infinito por esta vía. `renderSearch()` reconstruye `matches` desde cero en
  cada llamada caminando `ROOT.children` — nunca cachea referencias entre
  renders — así que la poda (`node.parent.children = ...filter(...)`) se
  refleja igual de correctamente en resultados de búsqueda que en el árbol,
  confirmado también empíricamente en el escenario C de arriba.
- **Bridge real** (`launchctl list` confirma el LaunchAgent vivo en
  `127.0.0.1:8737`, proxeado por Caddy en `:8080`): `POST /-/delete` con un
  fichero inexistente → `404 {"error": "no existe"}`; con un directorio real
  existente (`~/src/html/revel-knowledge`, confirmado intacto después) → `400
  {"error": "no se pueden borrar directorios"}` — mismo shape `{error: string}`
  que `wireTrash` parsea vía `data.error`. No se ejecutó ningún borrado real
  contra contenido genuino de Fran (solo casos de rechazo, sin efectos por
  diseño); el hito 1 (ya aprobado) cubre exhaustivamente el camino de éxito.
- Estética: colores/tamaños/tipografía de `.trash` coherentes con el resto de
  `.entry .meta` y con el rojo `#e5484d` ya establecido como color de error
  semántico (`.share-msg.error`); revelado por `opacity`/`pointer-events` (no
  `display`) preserva el tab-order, coherente con el patrón ya usado en
  `.docbar .back:disabled`. Icono `TRASH` con el mismo `stroke-width`/
  `stroke-linecap`/`stroke-linejoin` que `FOLDER`/`DOC`/`SHARE`.
- **Cero comentarios nuevos**: `git diff ... | grep "^+" | grep -i "//\|/\*"`
  sobre el diff completo no encuentra ninguna línea añadida que sea un
  comentario — el código nuevo (`TRASH`, `.trash` CSS, `showEmptyReader`,
  `wireTrash`, `parent: node`) no lleva ninguno, coherente con la regla
  aplicada en las rondas de `scriptorium-share`.
- Confirmado por lectura completa del diff que no se tocó ninguna línea de
  `openDoc`, `wireShare`/`doShare`/`shareWrapFor`/`shareRefs`,
  `exportPdf`/`printCss`/`pageBg`, `loadShares`/`shareKeyOf`, `buildNode`,
  `renderTree`, `toggle`/`reveal`/`crawl`, ni la paleta Cmd+K — sin
  regresiones en esas rutas.
- Limpieza: ningún fichero de prueba dejado en `~/src/html` ni en el repo; los
  harnesses de Chrome headless vivían solo en `/tmp` y se borraron al terminar;
  no se publicó ningún artifact ni se ejecutó ningún borrado real contra
  contenido de Fran.

## Para pasar a APPROVED

Corregir el Bloqueante 1 (doble-click rápido ejecuta un borrado real sin
ventana de confirmación perceptible) es lo único pendiente. El resto de la
lógica —incluida la interacción con `/-/share` en vuelo, la búsqueda activa, y
la poda en memoria vía `node.parent`— está verificada y correcta.

---

# Re-review — hito 2: catalog-delete-button (ronda 2)

## Veredicto: APPROVED

## Confirmación del bloqueante de la ronda 1 — RESUELTO

`macos/scriptorium-browse.html:439-485`. El fix añade `armedAt = Date.now()` al
entrar en `confirm` (línea ~455) y, en la rama que ya tenía la clase `confirm`,
`if (Date.now() - armedAt < 350) return;` **antes** de `clearTimeout(timer)`
(línea ~460-461) — el orden es el correcto: ignorar el click no toca el
temporizador de expiración de 3s en absoluto.

Verificado ejecutando el código real extraído del fichero en Chrome headless
con DOM real, `fetch` mockeado y `--virtual-time-budget` (no confiando solo en
la evidencia del builder):

- **Frontera exacta**: `dt=349ms` → click ignorado, el botón sigue en
  `confirm` sin haber llamado a `fetch`; `dt=350ms` → sí ejecuta el borrado
  (consume la respuesta simulada de la cola). Confirma que el operador `<
  350` (estricto) hace que 350 sea ya el primer valor que ejecuta, consistente
  con lo que declaró el builder (`dt=300` no borra, `dt=400`/`dt=450` sí).
- **Doble-click rápido real** (`dt≈40ms`, el mismo repro que motivó el
  bloqueante de la ronda 1): 0 llamadas a `/-/delete`, el botón permanece en
  `confirm` — el bloqueante queda cerrado.
- **El timer de expiración de 3s NO se reinicia por un click ignorado**
  (requisito 2 del encargo): dispatché un primer click en t=0 (arma el timer
  para expirar en t≈3000) y un segundo click ignorado en t=100. Si el timer se
  hubiera reiniciado a partir de ese click ignorado, expiraría en t≈3100; si no
  se reinició (comportamiento correcto), expira en el t≈3000 original. Medido
  en t=3050 (post-3000, pre-3100): `stillConfirmAt3050: false` — ya había vuelto
  a `idle`, confirmando que el timer original nunca se tocó.
- **Caso inverso pedido (requisito 1)**: un usuario legítimo cuyo segundo click
  cae en la ventana de 0-349ms simplemente ve su click ignorado y **permanece
  en `confirm`** (sin resetear clases ni temporizador, sin mensaje de error) —
  no hay ningún "caso roto" nuevo, solo tiene que volver a pulsar una vez más
  dentro de la misma ventana de 3s ya visible. Fricción mínima y sin ambigüedad
  visual (el botón sigue mostrando "¿borrar?" todo el tiempo).
- **¿Es razonable 350ms?** Sí, como punto medio defendible: el tiempo de
  reacción visual simple en humanos ronda 200-300ms, más el tiempo de
  ejecución motora de un segundo click discreto — una confirmación
  genuinamente deliberada ("vi el cambio, decido pulsar otra vez") ronda
  habitualmente 400ms-2s, mientras que un doble-click reflejo/accidental de
  ratón o trackpad (el caso que motivó el bloqueante) suele estar muy por
  debajo, en el rango de 100-250ms. 350ms filtra el caso reflejo verificado sin
  imponer fricción real al caso deliberado (y el coste de un falso positivo es
  solo "pulsa una vez más", no un error ni un bloqueo permanente). No es una
  garantía perfecta contra un doble-click deliberadamente rápido de 360-400ms,
  pero ese caso ya no es "accidental" en el mismo sentido — es indistinguible
  de una confirmación real y rápida, y aceptar ese límite es razonable para
  esta herramienta personal.

## Sugerencias de la ronda 1 — RESUELTAS

- **Mensaje de error alineado con `doShare`**: `err instanceof TypeError ?
  'error: no se pudo conectar con el bridge' : (err.message || 'error')`
  (`macos/scriptorium-browse.html:~479`). Verificado con un `fetch` que
  rechaza con `TypeError('Failed to fetch')`: `textAfterBridgeDown: "error: no
  se pudo conectar con el bridge"`, en español, consistente con `doShare`. El
  nodo **no** se poda (`nodeStillInRootAfterBridgeDown: true`) y el botón se
  reactiva (`disabled: false`), igual que antes de este fix — sin regresión en
  la ruta de error.
- **`aria-label` dinámico por estado**: `idle` → "Borrar T", `confirm` →
  "Confirmar borrado de T", `borrando` → "Borrando T", `error` → "Error al
  borrar T: error: no se pudo conectar con el bridge" — verificado leyendo
  `getAttribute('aria-label')` en cada transición real del botón, no solo el
  código. Cierra la Sugerencia 2 de la ronda 1 (un lector de pantalla ya
  anuncia el cambio de estado, incluida la propia palabra "Confirmar" en el
  paso intermedio). Tras descartar el error con un click, vuelve a "Borrar T"
  limpio.

## Verificación adicional de esta ronda

- `node --check` sobre el `<script>` re-extraído → sin errores.
- `git diff HEAD -- macos/scriptorium-browse.html | grep "^+" | grep -i
  "//\|/\*"` → sin resultados, sigue sin comentarios nuevos.
- Releído el diff completo: los únicos cambios respecto a la ronda 1 son
  `armedAt`, el `if (Date.now() - armedAt < 350) return;`, el `err instanceof
  TypeError` y las cuatro llamadas a `btn.setAttribute('aria-label', ...)`
  (una por estado). Nada más se tocó — ni `showEmptyReader`, ni la poda vía
  `node.parent`, ni la integración con `doShare`/`shareWrapFor`, ni el resto
  del árbol/búsqueda/paleta, que ya habían quedado verificados como correctos
  en la ronda 1 y no forman parte de este diff.
- Limpieza: harnesses de Chrome headless solo en `/tmp`, borrados al terminar;
  ningún fichero de prueba en `~/src/html`; no se publicó ningún artifact ni se
  ejecutó ningún borrado contra contenido real de Fran (todas las pruebas
  usaron `fetch` mockeado).

## Sugerencias restantes (no bloqueantes, sin cambios respecto a la ronda 1)

- `<button>` anidado en `<a>`: aceptado como deuda técnica documentada, sin
  impacto funcional verificado (ver ronda 1).

La aceptación del hito 2 está cubierta: flujo completo hover→papelera→confirmar
funcional, doble-click accidental ya neutralizado con verificación empírica
propia, borrado del doc abierto cierra el lector, bridge parado da error
legible en español sin romper el visor, `node --check` limpio, sin regresiones
en compartir/PDF/búsqueda/paleta.
