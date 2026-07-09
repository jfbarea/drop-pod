# Review — hito 5: hide-link-until-shared

## Veredicto: APPROVED

## Bloqueantes

Ninguno.

## Sugerencias

Ninguna.

## Riesgos

Ninguno nuevo. El fix es puramente de CSS, no toca superficie de red/seguridad
ya cubierta por las reviews de los hitos 1-3.

## Verificación realizada

- Lectura de `plan/scriptorium-share/PLAN.md` (hito 5) y `_state.json`: feedback
  de HUMAN_REVIEW de Fran (el enlace «artifact» se veía antes de existir el
  artifact, por el choque `.docbar a{display:inline-flex}` (autor) vs.
  `[hidden]{display:none}` (UA), donde gana el autor por especificidad aunque el
  UA sea "más reciente" en la cascada por defecto del navegador).
- `git diff HEAD --stat -- macos/` → único fichero tocado en esta ronda:
  `macos/scriptorium-browse.html` (125 inserciones, 0 borrados, sobre el HEAD
  limpio anterior a los hitos 3-5). `scriptorium.Caddyfile` y
  `scriptorium-share.py` sin diferencias.
- Fix: `[hidden]{display:none!important}` añadida justo tras el reset universal
  `*{box-sizing:border-box;margin:0;padding:0}` (`macos/scriptorium-browse.html:43`),
  en vez del parche puntual `.docbar a[hidden]{display:none}` que sugería el
  PLAN. Evalué el cambio de enfoque:
  - Es la solución estructuralmente correcta: cualquier regla de autor con
    `display` (no solo `.docbar a`) sobre un elemento con el atributo `hidden`
    reproduciría el mismo choque; una regla global con `!important` lo cierra
    de una vez para todo el fichero en vez de ir parcheando caso por caso cada
    vez que se añada un nuevo `display` de autor sobre un elemento `hidden`.
  - Verifiqué con `grep -n "!important"` que **no hay ningún otro `!important`
    sobre `display`** en la página del visor (el único otro bloque de
    `!important` es el `@media print` inyectado dinámicamente dentro del
    `<iframe>` del documento exportado a PDF, un documento distinto, sin
    ninguna relación con esta regla), así que no hay conflicto de dos
    `!important` pisándose.
  - La posición (justo tras el reset universal) es correcta y, dado el
    `!important`, en realidad no depende del orden: gana a cualquier regla de
    autor sin `!important` sin importar dónde esté declarada en la cascada.
- **Grep de `hidden` en todo el fichero**: `#share-link` es el **único**
  elemento HTML con el atributo `hidden`, y `link.hidden` en el JS
  (`wireShare`/`doShare`) es el único código que lo manipula (siempre para
  mostrarlo tras una URL real, nunca para ocultar nada más). Ningún otro
  elemento del visor (paleta Cmd+K, `.reader` en mobile, `.palette-backdrop`)
  usa el atributo `hidden`: todos esos "ocultamientos" existentes se hacen con
  clases (`.open`, `body.reading`), que no seleccionan `[hidden]` y por tanto no
  pueden verse afectados por la regla nueva. Repaso completo confirmado con
  `grep -n "hidden"` y `grep -n "display:"` sobre el fichero completo.
- **Verificación empírica con Chrome headless** (`--headless=new --dump-dom`)
  montando el `<style>` **verbatim** del fichero real actual (sin el comentario
  que había añadido el builder y que el orquestador ya retiró) sobre un
  `<a class="share-link" id="share-link">` dentro de `<div class="docbar"><span
  class="share">`:
  - Con el atributo `hidden` presente → `getComputedStyle(...).display` =
    `"none"`.
  - Sin el atributo `hidden` → `"flex"` (no `"none"`; el valor no es
    `"inline-flex"` como en la declaración de autor por la blockificación
    estándar de CSS que sufre todo elemento que es a la vez hijo flex de
    `.docbar .share{display:inline-flex}` — comprobado también en un caso
    mínimo aislado que `inline-flex` se preserva literal cuando el elemento NO
    es un flex item; es un detalle de la cascada normal de CSS, no un efecto de
    la regla nueva, y no cambia la conclusión: sin `hidden` el enlace es
    visible).
  - Con `document.styleSheets` inspeccioné qué reglas coinciden con el
    elemento y tienen `display`: solo `.docbar a, .docbar .back` (sin la regla
    `[hidden]`, que no aplica cuando no hay atributo). Confirma que el
    `!important` nuevo es el único factor que cambia el resultado a `none`
    cuando el atributo está presente.
- **`node --check`** sobre el `<script>` extraído (placeholders Go-template
  sustituidos) → sin errores de sintaxis.
- Repasados los tres estados del botón (reposo/publicando/✓ copiado/error) en
  el propio código: ninguno depende de `[hidden]` salvo el propio
  `#share-link` (que se muestra/oculta exactamente igual que antes, solo que
  ahora la ocultación en reposo/error-sin-link-previo sí funciona). Sin
  cambios en `doShare`/`wireShare`/`shareWrapFor` más allá de la regla CSS.
- Confirmado (encargo explícito del coordinador) que los cuatro comentarios que
  pedí eliminar en la ronda 3 de la review de `viewer-button` siguen fuera del
  fichero, y que el comentario nuevo que había añadido el builder para este
  hito ya no está (lo retiró el orquestador antes de esta revisión, coherente
  con la regla de cero comentarios).
- No se publicó ningún artifact real; toda la verificación fue estática
  (grep, Chrome headless sobre HTML aislado con el CSS real, `node --check`).
  Ficheros temporales de la verificación borrados al terminar.

La aceptación del hito 5 está cubierta: el enlace no se ve mientras no hay
artifact, aparece tras publicar con éxito, y un doc ya compartido lo muestra al
abrirse — verificado sobre el DOM real (computed style), no solo a ojo — y no
hay regresión en los estados del botón ni en ningún otro uso de `display`/
`hidden` del resto del visor.
