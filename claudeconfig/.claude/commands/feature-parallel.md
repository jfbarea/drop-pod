---
description: Feature nueva implementada en olas paralelas. Varios `worker` a la vez sobre particiones disjuntas de ficheros, gate de integración por ola. Requiere spec APPROVED, igual que /feature.
argument-hint: "[slug de la feature con spec APPROVED]"
---

Implementa lo que la spec ya decidió, pero repartiendo el trabajo entre varios agentes que corren a la vez.

El argumento (opcional): $ARGUMENTS

La diferencia con `/feature` es sólo el motor: `/feature` encadena `builder` → `reviewer` hito a hito; aquí el plan es un grafo de dependencias, las tareas sin dependencias entre sí se ejecutan simultáneamente en **olas**, y tú eres el orquestador. La puerta de entrada es la misma: sin spec `APPROVED` no se implementa nada.

**Tú eres el único que commitea y el único que escribe estado.** Los `worker` no tocan git ni `_state.json`. Esto no es un detalle de estilo: es lo que impide que dos agentes concurrentes se peleen por `.git/index.lock` y lo que mantiene los commits atómicos.

## 1. Arranque

1. Localiza `plan/specs/<slug>.md` con `status: APPROVED` para la feature pedida.
   - Si no existe ninguna, **para y dime que hay que pasar por `/specs`**. No te inventes el alcance ni me interrogues aquí.
   - Si existe pero está en `DRAFT` o `REVIEW`, dímelo y espera.
   - Si te insisto en seguir sin spec aprobada, es mi decisión: sigues, pero escribes en `PLAN.md` que se implementó sin spec y qué asumiste.
2. Lee `SPEC.md` para el contexto global y `plan/specs/<slug>.md` como input principal. Si `plan/_active` existe, lee también `plan/<activa>/PLAN.md` y el `status` de `plan/<activa>/_state.json`.
3. Si no existe `plan/`, créalo. `plan/research/` y `plan/specs/` son globales; el resto vive por feature.
4. Comprueba si ya hay una PR abierta parecida: `gh pr list --state open --json number,title,headRefName,author,url`. Si hay solape, notifícamelo (número, título, autor, URL y en qué se parece) y espera mi decisión antes de crear nada. Si `gh` falla o no hay remote, dilo y sigue.

## 2. El plan es un grafo, no una lista

Crea `plan/<slug>/` reusando el `<slug>` de la spec, con `PLAN.md`, `_state.json` y `reviews/`. Escribe el slug en `plan/_active`.

Cada tarea declara **de qué depende** y **qué ficheros va a tocar**. Las olas son los niveles topológicos del grafo: la ola 1 son las tareas sin dependencias, la ola 2 las que sólo dependen de la ola 1, y así.

```markdown
# <feature> — plan paralelo

Spec: `plan/specs/<slug>.md` (v<N>, APPROVED)

## Tareas

| id  | tarea          | ola | deps | criterios  | ficheros                          |
|-----|----------------|-----|------|------------|-----------------------------------|
| t01 | contratos-api  | 1   | —    | CA-1       | `src/api/types.ts`                |
| t02 | endpoint-list  | 2   | t01  | CA-2, CA-3 | `src/api/list.ts`                 |
| t03 | vista-listado  | 2   | t01  | CA-4       | `src/ui/List.tsx`                 |
| t04 | tests-endpoint | 2   | t01  | CA-2       | `tests/api/list.test.ts`          |

## t01 — contratos-api
**Objetivo**: …
**Criterios de la spec que cierra**: CA-1
**Ficheros (exhaustivo, incluidos los que hay que crear)**: `src/api/types.ts`
**Hecho cuando**: …
```

Reglas del grafo:

- **Cada criterio de aceptación de la spec cae en al menos una tarea**, y cada tarea referencia los criterios que cierra. Si un criterio no encaja en ninguna tarea, párame antes de seguir.
- **La ola 1 es siempre de contratos** cuando hay más de una ola: firmas, tipos, esquemas de datos, constantes compartidas. Lo que hunde una ola paralela no es el código, es que dos workers asuman firmas distintas del mismo módulo. Con el contrato ya escrito en el árbol, no hay nada que asumir.
- **La lista de `ficheros` es exhaustiva y es el contrato de exclusión mutua.** Incluye los que hay que crear. Si no sabes qué ficheros toca una tarea, no está lista para paralelizarse: mírate el código hasta saberlo.

`_state.json`:

```json
{
  "status": "BUILDING",
  "mode": "parallel",
  "spec": "plan/specs/<slug>.md",
  "wave": 1,
  "tasks": [
    {"id":"t01","slug":"contratos-api","wave":1,"deps":[],"criteria":["CA-1"],
     "files":["src/api/types.ts"],"status":"PENDING"}
  ]
}
```

Estados de tarea: `PENDING` → `BUILT` (worker terminado, sin commitear) → `DONE` (commiteada) · `CHANGES_REQUESTED` · `BLOCKED` · `ABORTED`.

Enséñame el plan con sus olas y espera OK antes de lanzar nada.

## 3. Ejecución de una ola

**Antes de lanzar:**

1. **El árbol tiene que estar limpio.** `git status --porcelain` vacío. Si hay cambios sueltos, párate: al cerrar la ola no podrás distinguir lo que escribió cada worker de lo que ya estaba, y la atribución por ficheros es lo único que sostiene los commits atómicos. Dímelo y ofréceme commitear o apartarlos; no lo decidas tú.
2. **Verifica que la partición es disjunta.** Los `ficheros` de las tareas de la ola, dos a dos, sin intersección. Si dos se solapan: o las fundes en una tarea, o una pasa a la ola siguiente. No lances una ola con partición solapada.
3. **Lanza todos los workers de la ola en un solo mensaje**, con una llamada al tool `Agent` por tarea en el **mismo bloque**. En mensajes distintos se ejecutan en serie y no has paralelizado nada.

El prompt de cada `worker` lleva: id y objetivo de la tarea, la lista exhaustiva de ficheros, los criterios de la spec que cierra, la ruta de la spec y del `PLAN.md`, y el recordatorio de que hay otros workers escribiendo en el mismo árbol.

**Al terminar todos:**

4. **Reconcilia la partición.** `git status --porcelain` te da el conjunto real de ficheros tocados. Compáralo con la unión de los declarados:
   - Fichero tocado que **nadie declaró** → desborde. No commitees. Dime cuál, qué worker lo reporta en su `FILES_OUTSIDE_PARTITION`, y espera.
   - Fichero declarado que **nadie tocó** → la tarea no hizo lo que dijo. Dímelo antes de dar la ola por buena.
5. **Si algún worker volvió `ABORTED`**, su trabajo parcial sigue en el árbol. **No lo borres y no lo commitees.** Nombra los ficheros, dime el motivo que devolvió, y espera decisión.
6. **Gate de integración.** Suite completa, lint y build **del conjunto**, no de cada tarea. Los tests de cada worker en verde por separado no dicen nada del conjunto. En rojo: no abras ola nueva, no lances `integrator`, dime qué falla.
7. **`integrator`** sobre la ola entera. Devuelve veredicto por tarea y veredicto de ola; el informe queda en `plan/<slug>/reviews/wave-<N>.md`.
   - `CHANGES_REQUESTED` → relanza **sólo** los workers de las tareas con bloqueantes, con el informe en el prompt, y vuelve al paso 4.
   - `BLOCKED` → párate y dímelo.
8. **Commits, uno por tarea**, en orden topológico: `git add` con los ficheros de esa tarea y mensaje `feat(<slug>): <resumen de la tarea>`. Así cada commit sigue siendo un cambio lógico aunque el trabajo se hiciera en paralelo. Anota el `commit_sha` en su tarea y ponla en `DONE`.
9. Sube `wave` en `_state.json`, resúmeme la ola en tres líneas y abre la siguiente.

## 4. Cuándo NO paralelizar

Decirlo a tiempo es parte del trabajo. Párame y proponme `/feature` cuando:

- **El grafo sale en cadena** — cada tarea depende de la anterior. N agentes en serie hacen lo mismo que uno, más caro y con más piezas que se rompen.
- **Una ola tiene una sola tarea.** No montes ola: no hay nada que paralelizar y el ciclo secuencial sale más barato.
- **La partición disjunta no sale sin inventarla.** Una partición falsa es lo peor de los dos mundos: te da todo verde y te deja ficheros pisados.
- **Techo práctico: 4 workers por ola.** Por encima, el gate y la integración se vuelven el cuello de botella y el riesgo de desborde se multiplica sin que baje el tiempo total.

## 5. Estado de la feature

`status` en `plan/<slug>/_state.json`, separado del estado por tarea:

- `BUILDING` — quedan olas por ejecutar.
- `HUMAN_REVIEW` — todas las tareas en `DONE` y la feature espera mi revisión. Lo pones tú al cerrar la última ola: comprueba criterio por criterio que la spec queda satisfecha, genera el walkthrough para el scriptorium con el diff completo de la feature (instrucciones en `walkthrough.md`, junto a este fichero) y avísame. En este estado NO abras olas, NO abras PR y NO desactives la feature.
- `DONE` — le he dado el visto bueno tras mi revisión.

Mi feedback durante `HUMAN_REVIEW` se convierte en tareas nuevas `PENDING` en una ola nueva, y el status vuelve a `BUILDING`.

## 6. Límites

- **No decides qué se construye.** Si durante la implementación aparece algo que la spec no contempla o la contradice, párame y lo resolvemos en `/specs`. No lo decidas tú y no lo decida un worker.
- Sólo trabajas dentro de `plan/<slug>/`. No toques otras features.
- No abres PR.
