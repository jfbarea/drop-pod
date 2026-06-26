Investigación pre-feature. Iterativa y dialógica. Output: HTML rico para humanos.

## Cuándo usar
- Problema grande o cambio amplio que conviene pensarse antes de implementar.
- Evaluar opciones, trade-offs, riesgos antes de comprometer un PLAN.md.
- NO uses /research para tareas pequeñas (/quick) ni para features ya pensadas (/feature directo).

## Flujo

1. Si no te he dicho qué investigar, pregunta: ¿cuál es el problema?
2. Si falta contexto crítico, haz 2-3 preguntas máximo: restricciones, criterio de éxito, deadlines.
3. Crea `plan/research/<slug>.html` (slug en kebab-case, derivado del problema):
   - HTML autocontenido, CSS inline, sin dependencias externas.
   - Estado inicial: badge `DRAFT`.
   - Secciones obligatorias: Problema · Contexto y restricciones · Opciones (2-4) · Trade-offs · Preguntas abiertas · Recomendación · Sketch alto nivel · Riesgos · Bitácora.
   - Bitácora: `<details>` al final con `v1 — primer borrador`.
4. Tras crearlo, indica cómo verlo: `cd <repo> && serve plan/research`.

## Iteración

5. Espera feedback en lenguaje natural. Aplica con `Edit` (quirúrgico) o `Write` (reestructura grande).
6. Cada vuelta: añade una entrada a la bitácora `vN — resumen corto del cambio`.
7. Tras cada modificación: resume qué cambió y di "refresca el navegador".
8. Si llevamos 6+ iteraciones sin promover, pregunta explícitamente: ¿cerramos o seguimos explorando?

## Mantente en investigación
- Sketch de implementación máximo ~15 líneas, alto nivel, sin código real.
- Si te piden código detallado, frena: "eso es para /feature después del hand-off, ¿cerramos research?".

## Estados
- `DRAFT` — primera pasada, opciones abiertas, preguntas sin cerrar.
- `REFINED` — opciones cerradas, recomendación firme. Solo cambia el badge cuando el usuario lo apruebe.
- `READY_FOR_FEATURE` — aprobado para hand-off. Solo se llega aquí desde REFINED.

## Hand-off a /feature

Cuando el usuario diga "vamos a feature" / "hagamos feature":
1. Verifica que el estado es `REFINED`. Si está en `DRAFT`, niégate: "el research aún está en DRAFT, ¿lo promovemos antes?".
2. Genera/actualiza `plan/research/<slug>.md` (~30-50 líneas: problema, opción elegida, sketch, riesgos clave). Es el resumen destilado para el architect, barato en tokens.
3. Cambia el badge del HTML a `READY_FOR_FEATURE` y añade entrada a bitácora.
4. Commitea: `research(<slug>): handed off to feature`.
5. Continúa con el flujo de /feature pasando el contenido de `plan/research/<slug>.md` al architect como input principal.

## Commits

- No commitees automáticamente durante iteración. Es un working doc.
- Solo commitea cuando el usuario apruebe estados:
  - Al promover a REFINED: `research(<slug>): refined`
  - En el hand-off: `research(<slug>): handed off to feature`
