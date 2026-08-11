---
description: Especificación de una feature, construida a base de preguntas de una en una. Fuente de verdad en plan/specs/<slug>.md; se lee en el scriptorium. Es la puerta obligatoria antes de /feature.
argument-hint: "[slug o descripción de la feature — opcional; sin argumento retoma la spec activa]"
---

Especificación detallada de una feature, escrita entre los dos. Yo respondo, tú redactas.

El argumento (opcional): $ARGUMENTS

Esta es la puerta antes de `/feature`: sin una spec en `APPROVED` no se implementa nada. Aquí no se escribe código de aplicación, no se abren ramas y no se crean hitos.

## Artefactos

- **Fuente de verdad**: `plan/specs/<slug>.md` (kebab-case). Versionado, diffable, y lo que después leen `/feature`, `builder` y `reviewer`.
- **Vista para leer**: `~/src/html/<repo-name>/spec-<slug>.html`, con las reglas de HTML del `CLAUDE.md` global (estilo scriptorium, dark fijo, tipografía, SVG para cualquier diagrama, bloque `@media print`, rotación a `archive/` antes de escribir, legible en iframe estrecho). Es un render del `.md`, nunca una segunda fuente: si divergen, manda el `.md`.
- `plan/specs/_active` contiene el slug de la spec en curso.

El `.md` lleva cabecera legible por máquina:

```
---
slug: <slug>
status: DRAFT
version: 1
---
```

## Arranque

1. Determina de qué spec hablamos:
   - Argumento que coincide con un `plan/specs/<slug>.md` existente → la abres y seguimos donde lo dejamos.
   - Argumento que describe algo nuevo → propón un `<slug>` y confírmalo conmigo antes de crear el fichero.
   - Sin argumento → si `plan/specs/_active` apunta a una spec sin `APPROVED`, retómala; si no, pregúntame qué quiero especificar.
2. Si venimos de `/research` con hand-off, lee `plan/research/<slug>.md` y úsalo como material de partida: no me vuelvas a preguntar lo que ya está decidido ahí. El interrogatorio arranca por lo que el research dejó abierto.
3. Antes de la primera pregunta, oriéntate en el repo: lee `SPEC.md` si existe, y localiza el código que la feature va a tocar. Las preguntas tienen que estar informadas por lo que ya hay, no ser un cuestionario genérico.
4. Comprueba si hay una PR abierta parecida (`gh pr list --state open --json number,title,headRefName,author,url`). Si hay solape, dímelo (número, título, autor, URL y en qué se parece) antes de seguir. Si `gh` falla o no hay remote, dilo y continúa.

## El interrogatorio

Esta es la parte que importa. Es un diálogo, no un formulario que rellenas solo.

- **Una pregunta por turno. Una.** Nunca me lances dos preguntas en el mismo mensaje ni un bloque de puntos a resolver. Preguntas, espero, respondo, y con mi respuesta decides la siguiente.
- Usa `AskUserQuestion` con **una sola pregunta** por llamada, con opciones concretas cuando tengas una hipótesis (la primera, tu recomendación); yo siempre puedo escribir la mía. Cuando la pregunta sea abierta de verdad y las opciones la estrecharían, pregunta en texto plano.
- Cada pregunta va motivada: por qué la haces y qué cambia en la spec según lo que responda. Nada de preguntar por rellenar una sección.
- **Sin número fijo de preguntas.** Sigues hasta que todas las secciones obligatorias tengan contenido real y ninguna pregunta abierta bloquee la implementación. Ni cortas por parecerte largo, ni alargas por parecerte corto.
- No preguntes lo que puedes averiguar leyendo el repo. Si la respuesta está en el código, míralo y tráeme el dato ya resuelto para que solo confirme.
- **Discute, no obedezcas.** Si una respuesta mía se contradice con otra anterior, deja un caso sin cubrir, o es más frágil de lo que parece, dímelo en ese momento y propón la alternativa. Anotar sin más una decisión que sabes que es mala no es hacer tu trabajo.
- Después de cada respuesta, escribe lo acordado en el `.md` con `Edit` (quirúrgico). El documento crece a la vez que la conversación; no acumules diez respuestas para volcarlas al final.
- Cuando cierres una sección, resúmeme en una o dos líneas qué ha quedado escrito antes de pasar a la siguiente.

## Secciones obligatorias del `.md`

1. **Problema** — qué duele hoy y por qué ahora. Sin esto la spec es una lista de deseos.
2. **Alcance** — qué entra, en comportamiento observable.
3. **No-objetivos** — qué queda explícitamente fuera. Sección obligatoria: es la que evita que la implementación se desborde.
4. **Comportamiento esperado** — el núcleo. Flujos, estados, reglas de decisión, qué ve el usuario en cada caso. Concreto y sin ambigüedad: si dos personas pueden leerlo distinto, aún no está especificado.
5. **Casos límite y errores** — entradas vacías, límites, concurrencia, fallos externos, qué pasa cuando algo no está disponible. Qué se hace en cada uno.
6. **Superficie afectada** — ficheros, módulos, contratos, datos, configuración y migraciones que toca; qué es compatible hacia atrás y qué rompe.
7. **Restricciones** — técnicas, de compatibilidad, rendimiento, seguridad, plazos.
8. **Criterios de aceptación** — numerados y verificables. Cada uno debe poder comprobarse con un test o una observación concreta; "funciona bien" no es un criterio.
9. **Riesgos y preguntas abiertas** — lo que sigue sin cerrar y qué habría que hacer para cerrarlo.
10. **Bitácora** — `v1 — primer borrador`, y una entrada por vuelta.

Si una sección no aplica de verdad, la dejas con una línea diciendo por qué no aplica. No la borras.

## Iteración

- Mi feedback en lenguaje natural se aplica con `Edit`; solo usa `Write` si hay que reestructurar el documento entero.
- Cada vuelta: sube `version` y añade `vN — resumen corto del cambio` a la bitácora.
- Tras cada modificación, dime en dos líneas qué ha cambiado.
- El HTML **no** se regenera en cada respuesta: durante el interrogatorio basta el `.md`. Lo generas cuando te lo pida ("dame el HTML", "quiero leerla") y siempre al cambiar de estado. Al generarlo, dime la ruta (el scriptorium lo cataloga solo).

## Estados

- `DRAFT` — interrogatorio en curso, hay secciones sin cerrar.
- `REVIEW` — todas las secciones tienen contenido y no queda pregunta abierta que bloquee. Lo pones tú al terminar el interrogatorio, generas el HTML y me avisas de que la spec espera mi lectura.
- `APPROVED` — le he dado el visto bueno explícitamente. Solo se llega desde `REVIEW`, y solo cuando yo lo digo: nunca te apruebes tu propia spec.

Mi feedback en `REVIEW` devuelve la spec a `DRAFT` y seguimos preguntando.

## Hand-off a /feature

Cuando yo diga que pasamos a implementar:

1. Verifica que el estado es `APPROVED`. Si no lo está, niégate y dime qué falta.
2. Regenera el HTML si el `.md` cambió después del último render.
3. Continúa con el flujo de `/feature` pasando `plan/specs/<slug>.md` como input principal: los hitos se derivan de los criterios de aceptación.

## Límites

- No implementes. Si te pido código durante la spec, frena: "eso es `/feature`, ¿cerramos la spec?". Fragmentos de contrato (una firma, un esquema de datos, un ejemplo de payload) sí valen cuando son lo especificado.
- No commitees automáticamente: es un documento de trabajo. Solo al cambiar de estado y si te lo pido: `specs(<slug>): review` / `specs(<slug>): approved`.
- No toques otras specs ni otras features.
