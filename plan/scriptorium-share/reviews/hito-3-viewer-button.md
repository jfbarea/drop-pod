# Review — hito 3: viewer-button

## Veredicto: CHANGES_REQUESTED

## Bloqueantes

1. **`loadShares()` cachea un fallo como si fuera un resultado bueno y vacío, y ya no vuelve a reintentar en toda la sesión de página.**
   `macos/scriptorium-browse.html:241-250`:
   ```js
   async function loadShares(force){
     if (sharesCache && !force) return sharesCache;
     try {
       const r = await fetch('/-/shares', {cache:'no-cache'});
       sharesCache = r.ok ? await r.json() : {};
     } catch (e) {
       sharesCache = sharesCache || {};
     }
     return sharesCache;
   }
   ```
   Si el `GET /-/shares` responde con un HTTP no-2xx (verificado en vivo contra el
   Caddy real de este Mac con el bridge parado — estado real hoy, pendiente de
   LaunchAgent hasta el hito 4 —: `curl -i http://localhost:8080/-/shares` →
   `502 Bad Gateway`, `Content-Length: 0`), la rama `r.ok ? … : {}` sobreescribe
   `sharesCache` con un objeto vacío **truthy**. La siguiente vez que se abra
   cualquier doc, `if (sharesCache && !force) return sharesCache;` corta antes de
   volver a intentar el fetch, así que ese `{}` fallido queda fijado como "mapping
   conocido" para el resto de la sesión de la pestaña — incluso después de que el
   bridge se recupere — y ningún doc ya compartido vuelve a mostrar su enlace
   automáticamente hasta que el usuario recargue la página a mano o publique algo
   (que sí fuerza `loadShares(true)`).
   Esto es justo el escenario de robustez que pide la aceptación del hito
   ("abrir un doc ya compartido muestra su enlace sin clicks") y el que hito 4 hace
   más probable en la práctica: el LaunchAgent con `KeepAlive` reinicia el bridge
   si crashea, y cualquier `GET /-/shares` que caiga en ese hueco de reinicio deja
   la sesión "envenenada" en silencio, sin ningún error visible para el usuario (a
   diferencia del flujo de `doShare`, que sí informa errores).
   El impacto práctico está acotado — el botón sigue diciendo "compartir" en vez de
   "actualizar", pero si el usuario lo pulsa, el bridge decide server-side por el
   mapping persistido (`.scriptorium-shares.json`) que es un re-share y devuelve la
   MISMA URL sin duplicar el artifact — así que no hay pérdida de datos, solo se
   pierde la comodidad de "verlo sin clicks" para el resto de la sesión.
   Arreglo simple: no fijar un resultado fallido como si fuera bueno, p. ej.
   `sharesCache = r.ok ? await r.json() : (sharesCache || {})` en la rama `r.ok`
   (igual que ya hace el `catch`), o dejar `sharesCache` sin tocar y devolver `{}`
   solo para esa llamada, de forma que la próxima apertura de doc reintente el
   fetch en vez de quedarse con el fallo cacheado indefinidamente.

## Sugerencias

1. **Mensaje de error duplica la palabra "error" en respuestas sin cuerpo JSON.**
   `macos/scriptorium-browse.html:291` cae a `` `error ${r.status}` `` cuando
   `data.error` es `undefined` (verificado: el 502 vacío de Caddy no trae body, así
   que `r.json().catch(() => ({}))` devuelve `{}`), y el catch de más abajo
   (`macos/scriptorium-browse.html:304`) antepone otro `` `error: ${e.message}` ``.
   El usuario ve "error: error 502". Cosmético, pero fácil de limpiar (p. ej. no
   anteponer "error: " cuando `e.message` ya empieza por "error").

2. **El botón «compartir»/«actualizar» acepta también `.htm` (case-insensitive) por el mismo `isHtml()` que ya usa el botón PDF, pero el bridge solo acepta sufijo exacto `.html`** (`macos/scriptorium-share.py:88`, `candidate.suffix != ".html"`). Un doc `.htm` mostraría el botón y siempre fallaría con 400. No hay ningún `.htm` real bajo `~/src/html` hoy (comprobado), así que es puramente teórico, y el fallo degrada bien (mensaje de error, visor usable) — no bloqueante.

3. **El `title` del botón se queda fijo en "Publicar como Artifact de claude.ai" aunque la etiqueta visible cambie a «actualizar»** tras encontrar un share existente o tras publicar con éxito (`macos/scriptorium-browse.html:487`). Detalle menor de pulido.

4. **Ventana de no-repintado si se reabre el mismo doc mientras una publicación anterior de ese mismo doc sigue en vuelo.** Trazado a mano: `doShare` guarda `wrap` por clausura (la instancia de DOM concreta creada en ese `openDoc`); si el usuario reabre el mismo doc antes de que esa publicación termine, `openDoc` crea un `wrap` nuevo y dejar el viejo desconectado. Cuando la publicación vieja resuelve, `loadShares(true)` sí actualiza `sharesCache` correctamente (esto es correcto y deseable), pero el guard `wrap.isConnected` impide pintar el enlace en el `wrap` **actual** (que es distinto al capturado). El usuario tiene que salir y volver a entrar al doc una vez más para verlo (esa segunda vez sí usará el `sharesCache` ya actualizado). No es incorrecto — no pinta nada en el doc equivocado, que era el requisito explícito — pero es una asimetría respecto al caso "cambiar a un doc distinto", que sí queda perfectamente aislado.

## Riesgos

Ninguno nuevo respecto a los ya documentados en las reviews de los hitos 1 y 2
(alcance de `Write` en la sesión desatendida de Claude, exposición de `/-/*` una
vez colgado de Caddy). Este hito añade superficie **cliente** (`fetch` a
`/-/share` y `/-/shares` desde JS del visor), pero es same-origin y no introduce
ningún endpoint ni permiso nuevo más allá de los ya expuestos por el hito 2.

## Verificación realizada

- Lectura de `plan/scriptorium-share/PLAN.md` (hito 3), `_state.json` y las
  reviews de los hitos 1 y 2.
- `git diff HEAD -- macos/scriptorium-browse.html macos/scriptorium.Caddyfile` y
  lectura completa de `macos/scriptorium-share.py` para contrastar exactamente
  qué cambió en este hito frente a lo ya aprobado.
- Confirmados los dos flecos de la review del hito 2: `hide` con glob
  (`macos/scriptorium.Caddyfile:38`, incluye `.scriptorium-shares-*.tmp`) y el
  comentario de `macos/scriptorium-share.py:13` en pasado.
- `caddy validate --config macos/scriptorium.Caddyfile --adapter caddyfile` →
  `Valid configuration` (mismo warning de formato preexistente, línea 11, no
  introducido aquí).
- `node --check` sobre el `<script>` extraído (placeholders Go-template
  sustituidos por valores dummy) → sin errores de sintaxis.
- Trazado línea a línea de `wireShare`/`doShare`/`openDoc` para los flujos
  pedidos:
  - **Reabrir el mismo doc**: `openDoc` reconstruye `readerEl.innerHTML` siempre
    (incluso reabriendo el mismo doc), así que se crean `#share`/`#share-btn`
    nuevos y `wireShare` reengancha el listener sobre el DOM nuevo — el botón
    sigue funcionando.
  - **Cambiar de doc con petición en vuelo**: `activeAbs` se actualiza al
    principio de `openDoc` antes de reconstruir el DOM; tanto `wireShare` como
    `doShare` comprueban `node.abs !== activeAbs || !wrap.isConnected` en cada
    punto tras un `await` antes de tocar el DOM. Verificado que el chequeo por
    `wrap.isConnected` por sí solo ya cubre el caso porque `innerHTML =` desconecta
    los nodos viejos del árbol; el chequeo por `activeAbs` es redundante pero
    inofensivo. El doc **nuevo** siempre nace con su botón habilitado de cero,
    sin ninguna interferencia del request viejo.
  - **Doble click rápido**: `btn.disabled = true` es la primera línea síncrona de
    `doShare` (antes de cualquier `await`), y los navegadores no disparan `click`
    sobre un `<button disabled>`, así que el segundo click no re-entra.
  - **Refresco del cache tras publicar**: `doShare` llama a `loadShares(true)`
    tras un `POST` exitoso, así que sí se refresca sin recargar la página — pero
    ver Sugerencia 4 para el caso concreto de reabrir el mismo doc mid-flight.
- **Robustez de red simulada en vivo** contra el Caddy de producción real de este
  Mac (bridge parado, que es su estado real hoy — el LaunchAgent es del hito 4):
  - `curl -i http://localhost:8080/-/shares` → `502 Bad Gateway`,
    `Content-Length: 0` (sin cuerpo). Esto es lo que dispara el Bloqueante 1.
  - `curl -i -X POST http://localhost:8080/-/share -d '{"path":"/test.html"}'` →
    mismo `502` vacío; en `doShare` esto se maneja bien (`r.json().catch(()=>({}))`
    → `{}` → `error ${r.status}` → mensaje visible, botón se reactiva), aparte del
    detalle cosmético de la Sugerencia 1.
  - AbortController a 200 s en el cliente vs. `TIMEOUT_SECONDS = 180` en el bridge
    (`macos/scriptorium-share.py:39`): el cliente espera más que el timeout del
    servidor, así que en el caso real de timeout el usuario ve el 504 real del
    bridge en vez de un abort del propio navegador — diseño correcto.
  - `shareKeyOf`/mapping: reverifiqué el razonamiento del builder (`node.abs` sin
    slash inicial vs. `rel_key` del bridge) contra `resolve_shared_path` en
    `macos/scriptorium-share.py:81-96`; consistente.
  - `.htm` vs `.html`: confirmado que `isHtml()` (regex `/\.html?$/i`) acepta
    `.htm` pero `resolve_shared_path` exige sufijo exacto `.html` — Sugerencia 2.
- Estética: el botón nuevo reutiliza la clase `.back` existente (mismo patrón de
  color/hover que PDF/catálogo), el icono `SHARE` sigue el mismo formato que los
  demás SVG inline de `openDoc` (sin `width`/`height`/`class`, delegando en la
  regla `.docbar svg` para tamaño/stroke), la animación de spin respeta la regla
  global `prefers-reduced-motion` ya existente, y el rojo de error `#e5484d` es
  nuevo en el fichero pero coherente como color semántico de error sobre `--paper`.
  Sin comentarios nuevos superfluos en el JS (el único comentario añadido es el
  encabezado de sección `/* ────────── botón «compartir»… ────────── */`, que seguía
  el patrón ya existente en el fichero para delimitar secciones, no explica código
  línea a línea).
- Confirmado con `grep`/lectura completa que no se tocó ninguna otra ruta:
  `renderTree`, `renderSearch`, `crawl`, `loadChildren`, `toggle`, `reveal`,
  `exportPdf`/`printCss`/`pageBg`, la paleta Cmd+K (`openPalette`/`renderPalette`/
  navegación por teclado) y `qEl`/búsqueda siguen exactamente igual que antes del
  diff — el único punto de enganche nuevo es la línea `if (isHtml(node))
  wireShare(node);` al final de `openDoc`.
- No se publicó ningún artifact real ni se arrancó el bridge de prueba en esta
  revisión (no hacía falta: las pruebas de robustez se hicieron contra el estado
  real del bridge, que está parado hasta el hito 4). No quedó ningún proceso ni
  fichero de prueba que limpiar.

La aceptación funcional "feliz" del hito (click → spinner → enlace, doc ya
compartido muestra enlace, bridge parado da error legible) está bien resuelta y
el trazado línea a línea de las condiciones de carrera pedidas (reabrir mismo
doc, cambiar de doc en vuelo, doble click) es correcto. Se pide CHANGES_REQUESTED
únicamente por el Bloqueante 1: es una regresión de sesión completa, fácil de
disparar (un único 502/504 transitorio del bridge) y fácil de arreglar sin tocar
el resto del diseño.

---

# Re-review — hito 3: viewer-button (tras correcciones)

## Veredicto: CHANGES_REQUESTED

## Bloqueantes fijados en esta vuelta (verificados)

- **Bloqueante 1 (poisoning de `loadShares`) — RESUELTO.** Verificado ejecutando la
  función real (`macos/scriptorium-browse.html:241-256`) con un `fetch` simulado:
  un `502` sin cuerpo y un `TypeError` de red devuelven `{}` para esa llamada
  **sin escribir `sharesCache`** (queda `null`), así que la siguiente apertura de
  doc reintenta; un `200` válido sí lo cachea; y un `502` posterior a un cache ya
  bueno **no lo pisa** (`sharesCache` se queda con el dato válido). Coincide
  exactamente con lo que declara el builder.
- **Dedupe del mensaje de error — RESUELTO.** `throw new Error(data.error ||
  \`HTTP ${r.status}\`)` (línea 318) ya no antepone "error" dos veces; el
  wording final es "error: HTTP 502", no "error: error 502".
- **`isShareable()` estricto — RESUELTO.** `/\.html$/i` (línea ~381) separado de
  `isHtml()` (que sigue aceptando `.htm` para PDF/iframe, intacta). El botón
  compartir y `wireShare` ahora usan `isShareable`, así que un hipotético `.htm`
  ya no ofrece un botón condenado a 400.
- **`title` dinámico — RESUELTO.** `SHARE_TITLE_NEW`/`SHARE_TITLE_UPDATE` se
  aplican en el render inicial, en `wireShare` (cuando ya hay entry cacheada), y
  en los tres desenlaces de `doShare` (éxito, error con/sin link previo).

## Bloqueante nuevo introducido por el propio fix

1. **`shareWrapFor` reconcilia por `data-abs` (mismo path), no por instancia — una
   respuesta tardía de una publicación vieja puede pintar su estado (link y,
   sobre todo, un mensaje de error obsoleto) sobre una instancia del docbar que
   ya vivió su propio ciclo posterior de esa misma acción.**
   `macos/scriptorium-browse.html:266-269, 298-353`.

   Repro real y plausible (no requiere condiciones de red exóticas): el bridge
   solo admite **una publicación a la vez de forma global** (`publish_lock` es un
   único `threading.Lock()` de proceso, no por-path — `macos/scriptorium-share.py:54,207-208`),
   así que si el usuario (a) pulsa «compartir» en un doc, (b) se impacienta,
   reabre el mismo doc (nace un wrap nuevo, en reposo, gracias al fix de
   `data-abs`) y (c) pulsa «compartir» otra vez mientras la primera sigue en
   curso en el servidor, esa segunda petición recibe un `409` **casi
   inmediato** del bridge real. Ese `409` pinta `msgEl` en rojo ("error: ya hay
   una publicacion en curso") y **reactiva el botón** (bloque `finally`,
   líneas 344-352) aunque la primera publicación sigue procesándose de verdad en
   el servidor. Cuando esa primera publicación termina con éxito más tarde,
   `shareWrapFor(node)` en su continuación (línea 320) encuentra ese mismo wrap
   (sigue siendo el único `#share` con ese `data-abs`) y pinta el enlace correcto
   y la etiqueta «✓ copiado» — **pero el código de éxito (líneas 319-331) nunca
   limpia `msgEl`**, así que el mensaje rojo "ya hay una publicacion en curso" de
   la petición fallida (b) se queda pegado junto al enlace ya publicado
   correctamente, indefinidamente, hasta que el usuario dispare otra acción de
   compartir (que sí resetea `msgEl` al principio) o vuelva a abrir el doc.

   Verificado ejecutando el código real (`shareWrapFor`/`doShare` copiados tal
   cual) en una simulación de Node con DOM stub y dos `fetch` controlados (A:
   éxito real y lento; B: `409` inmediato, disparado tras reabrir el doc y
   volver a pulsar). Estado final observado tras resolver A:
   ```
   { disabled: false, publishing: false, label: '✓ copiado',
     linkHidden: false, linkHref: 'https://claude.ai/REAL',
     msg: 'error: ya hay una publicacion en curso', msgError: true }
   ```
   Link y etiqueta correctos, pero el mensaje de error rojo sigue ahí sin motivo
   aparente para el usuario, que ve un estado contradictorio (¿funcionó o no?).

   Esto es justo el escenario que se pidió trazar ("error tardío tras navegar")
   y confirma que la solución por `data-abs` no distingue "la misma acción que
   inicié, reconectada tras reabrir" de "una acción distinta y más reciente para
   el mismo path que ya tuvo su propio desenlace" — ambas casan con el mismo
   `#share` en vivo porque solo comparan el path, no la operación. No es
   corrupción de datos (el bridge sigue siendo la fuente de verdad del mapping,
   y no hay forma de que dos publicaciones reales se pisen entre sí gracias al
   lock global — confirmado que un intento de reproducir "B gana con datos
   frescos mientras A sigue en curso" con un B que responde 200 rápido es
   **imposible en el sistema real**, porque el lock global bloquea cualquier
   segunda publicación real mientras la primera sigue viva), pero sí dejaría al
   usuario viendo un mensaje de error persistente e incorrecto sobre un share que
   en realidad salió bien.

   Sugerencia de arreglo (no prescriptivo): además de limpiar `msgEl` también en
   la rama de éxito (fix mínimo, tapa este caso concreto), lo más robusto sería
   no reconciliar solo por `data-abs` sino por una identidad de operación (p. ej.
   un contador/token global que se incrementa en cada `doShare` nuevo y que cada
   continuación compara antes de escribir, de forma que solo la última operación
   iniciada — no cualquier operación con el mismo path — tenga permiso de pintar
   su desenlace).

## Sugerencias pendientes (no bloqueantes, ya notadas en la vuelta anterior y sin cambios)

- Clipboard best-effort etiquetado siempre como "✓ copiado" aunque
  `navigator.clipboard.writeText` falle en silencio — aceptable, coincide con el
  PLAN ("fallback silencioso"), solo un matiz de wording.

## Verificación realizada en esta vuelta

- `git diff HEAD -- macos/scriptorium-browse.html` completo, línea a línea,
  contra el informe del builder.
- `node --check` sobre el `<script>` re-extraído → sin errores.
- `caddy validate --config macos/scriptorium.Caddyfile --adapter caddyfile` →
  `Valid configuration` (sin cambios en este fichero en esta vuelta).
- Simulación en Node (DOM mínimo, `fetch` controlado) de `loadShares` real:
  confirma que un fallo (502 u otro error) ya no escribe `sharesCache`, que la
  siguiente llamada reintenta, y que un fallo posterior a un éxito cacheado no
  lo pisa.
- Simulación en Node (DOM mínimo, `fetch` controlado) de `shareWrapFor`/`doShare`
  reales para dos escenarios:
  - Reabrir el mismo doc con una única publicación en vuelo (sin re-click): el
    resultado tardío se pinta correctamente sobre el docbar actual — el fix
    cumple lo que se pidió.
  - Reabrir el mismo doc **y volver a pulsar «compartir»** mientras la primera
    sigue en curso (409 real del lock global del bridge, confirmado leyendo
    `macos/scriptorium-share.py:54,130-132,207-208`): el mensaje de error de la
    segunda petición queda pegado permanentemente tras el éxito real de la
    primera — Bloqueante nuevo, detallado arriba.
- Confirmado que `isHtml()` sigue intacta (usada solo para PDF/iframe) y que
  `isShareable()` es la única usada para decidir si se renderiza el botón/`wireShare`.
- No se ha tocado ningún otro fichero en esta vuelta (`scriptorium.Caddyfile`,
  `scriptorium-share.py` sin diff nuevo); no hizo falta levantar bridge ni Caddy
  de prueba, las verificaciones de esta vuelta se hicieron sobre el código
  extraído y simulaciones aisladas, sin publicar nada real. Ficheros temporales
  de simulación borrados al terminar.

---

# Re-review — hito 3: viewer-button (ronda 3)

## Veredicto: CHANGES_REQUESTED

## Confirmación del bloqueante de la ronda 2 — RESUELTO

Verificado ejecutando el código **real** extraído del fichero (no una reescritura
a mano) en una simulación de Node con `fetch`/DOM/`clipboard` mockeados, con dos
interleavings:

- **Repro exacta del bloqueante** (409 real tras reabrir y re-pulsar, luego éxito
  real y tardío de la publicación original): tras el 409, `msg` queda en rojo
  como antes; tras el éxito real posterior, el fix limpia `msgEl` **antes** de
  pintar el enlace. Estado final observado:
  ```
  { label: '✓ copiado', linkHidden: false, linkHref: 'https://claude.ai/REAL',
    msg: '', msgError: false, title: 'Actualizar el Artifact publicado' }
  ```
  Sin rastro del error obsoleto. Coincide con lo declarado por el builder.

- **Interleaving simétrico** (éxito de una publicación más nueva pintado
  primero, luego llega un error tardío de la vieja): el `catch` de `doShare`
  solo escribe `msgEl`/`label`/`title` — nunca `link.href`/`link.hidden` — así
  que el enlace correcto ya pintado por la operación nueva **sobrevive intacto**;
  lo único que ensucia es un mensaje de error rojo superpuesto:
  ```
  { label: 'actualizar', linkHidden: false, linkHref: 'https://claude.ai/NEWSUCCESS',
    msg: 'error: timeout / 504 tardio', msgError: true, title: 'Actualizar el Artifact publicado' }
  ```
  Confirma exactamente lo que reportó el builder. Este residual es aceptable
  como trade-off consciente: dado el lock global del bridge, un esquema de
  "gana la última generación" evitaría este eco de mensaje, pero al precio de
  poder **enmascarar permanentemente un éxito real** cuando la operación
  "ganadora" es en realidad un 409 más reciente y la vieja (perdedora en el
  esquema de generación) es la que de verdad terminó compartiendo el doc — ese
  desenlace es peor (oculta un share que sí funcionó) que un mensaje de error
  cosmético junto a un enlace que sigue siendo correcto y visible. Además
  requiere reordenamiento de red entre dos respuestas de operaciones
  server-side ya secuenciadas por el lock (no una condición trivial de
  disparar). Coincide con el razonamiento del builder — de acuerdo con la
  decisión de no implementar el token/generación.

## Bloqueante nuevo (transversal, no es de lógica): comentarios en código nuevo

El fichero acumula, a lo largo de las tres rondas de este hito, **cuatro
bloques de comentarios explicativos** que violan la preferencia global y
explícita del usuario (`cero-comentarios-en-codigo`, cargada en todo el
contexto de sesión): *"No escribas comentarios en el código que generes.
Ninguno: ni redundantes ni de 'por qué'... Excepción solo si el usuario lo pide
explícitamente para un caso concreto."* Ninguno de estos cuatro cumple esa
excepción (nadie le pidió a Fran autorizarlos caso por caso):

1. `macos/scriptorium-browse.html:243-246` — comentario sobre `loadShares` (ronda 2).
2. `macos/scriptorium-browse.html:261-265` — comentario sobre `shareWrapFor` (ronda 2).
3. `macos/scriptorium-browse.html:323-330` — comentario nuevo de esta ronda sobre
   la invariante del lock global, que es el que el builder pidió evaluar
   explícitamente.
4. `macos/scriptorium-browse.html:391-393` — comentario sobre `isShareable` (ronda 2).

Nota de autocrítica: los puntos 1, 2 y 4 ya estaban presentes desde la ronda 2 y
no los señalé entonces — fue un descuido de esa revisión, no una aceptación
deliberada. Los marco ahora los cuatro juntos por consistencia, en vez de
aprobar el 3 y dejar pasar los otros tres con el mismo problema.

Respondiendo directamente a la pregunta del builder sobre el comentario del
punto 3: **no**, no calif ica como excepción válida bajo la regla tal y como
está escrita. La regla ya anticipa este argumento exacto — "si un fragmento no
se entiende sin comentario, refactoriza (renombra, extrae función) hasta que se
entienda solo" — así que la invariante del lock global debería quedar expresada
en la **estructura/nombres** (o documentada en el mensaje de commit de este
hito, que es donde la regla pide que viva el "porqué"), no en una nota inline.
Es información legítima y bien razonada — pero el sitio correcto para ella no
es el código fuente, por regla explícita del usuario.

No lo trato como puramente estético: la instrucción del sistema es explícita en
que estas preferencias "OVERRIDE any default behavior" y deben seguirse "exactly
as written", y el rol de reviewer incluye contrastar contra "convenciones del
proyecto". Pido su eliminación antes de aprobar.

## Verificación realizada en esta ronda

- `git diff HEAD -- macos/scriptorium-browse.html` completo; único fichero con
  cambios respecto a la ronda 2 (`git diff --stat` confirma `scriptorium.Caddyfile`
  y `scriptorium-share.py` sin diferencias nuevas).
- `node --check` sobre el `<script>` re-extraído → sin errores de sintaxis.
- Simulación en Node del código **real** (extraído del propio fichero con un
  `Function(...)`, no reescrito a mano) con `fetch`, `document.getElementById`,
  `navigator.clipboard` y `AbortController` mockeados, resolviendo manualmente
  cada petición pendiente por orden (incluida la llamada extra a `loadShares(true)`
  que dispara el propio éxito de `doShare`, que en el primer intento de
  simulación se me olvidó resolver y colgó el test — corregido). Los dos
  interleavings pedidos (repro exacta y su simétrico) dan los resultados
  descritos arriba.
- Releído el resto del diff (CSS, `isShareable`, `data-abs`, `openDoc`) frente a
  la ronda 2: sin cambios más allá del bloque de limpieza de `msgEl` y su
  comentario asociado.

## Para pasar a APPROVED

Único pendiente: quitar los cuatro comentarios señalados (o mover lo que valga
la pena preservar al mensaje de commit del hito). La lógica de concurrencia,
caché y estados está verificada y correcta.

---

## Cierre (ronda 3 → DONE)

El único bloqueante restante de la ronda 3 (cuatro bloques de comentarios nuevos
en `macos/scriptorium-browse.html`) lo aplicó el orquestador directamente por ser
una eliminación mecánica ya acotada: borrados los cuatro (loadShares,
shareWrapFor, invariante del lock en doShare, isShareable), conservando solo el
separador de sección `/* ────────── */` que es convención estructural del fichero.
Verificado tras el borrado: `node --check` del script extraído OK y `git diff` sin
ninguna otra línea de comentario añadida. La lógica ya estaba verificada como
correcta por el reviewer en esta misma ronda. Hito 3 → DONE.
