---
description: Quiz interactivo para el scriptorium — comprueba que entiendo un cambio antes de defenderlo en una review. Pregunta por el porqué, no por los nombres. Sin argumento cubre el trabajo recién terminado; con un PR, ese PR.
argument-hint: [PR (número, URL o rama) — opcional]
---

Quiz para el scriptorium: HTML interactivo con el que compruebo que he entendido un cambio antes de defenderlo en una review. Es hermano de `/walkthrough`: mismo ámbito, mismas reglas de HTML, otro formato de salida. No se encadena solo al final de ningún otro comando; lo invoco yo cuando quiero.

El PR (opcional): $ARGUMENTS

## 1. Delimita el cambio y reúne las fuentes

- **Con PR** (número, URL o rama): `gh pr view --json title,body,commits,baseRefName,headRefName,url` y `gh pr diff`. Si es una URL de otro repo, usa `gh -R <owner>/<repo>` y toma ese repo como `<repo-name>`. Cuando el hunk no baste, lee los ficheros completos en el head de la PR (`gh api "repos/<r>/contents/<path>?ref=<branch>"`), no el working tree local.
- **Sin PR**: el trabajo hecho en la sesión, commits nuevos más working tree frente a la base (`git diff <base>...HEAD`, `git diff HEAD`, o ambos). Si es ambiguo, pregúntame.
- Si en la sesión ya hay un walkthrough de ese cambio, o hay uno en `~/src/html/<repo-name>/` (o en su `archive/`) para el mismo PR o rama, es la fuente principal.
- Con el mismo peso que el código: la evidencia (logs, datos de producción, el issue) y lo que se habló en la conversación — qué se descartó y por qué, qué duda quedó abierta y cómo se resolvió. Son las preguntas que más cuesta contestar en una review.

## 2. Las preguntas

**10–12 preguntas** de opción múltiple, 4 opciones, una sola correcta. Nunca por el nombre de las cosas: por el porqué. Reparte entre estos tipos (el 8 solo si aplica):

1. **Causa raíz:** por qué fallaba, con el valor concreto que rompe.
2. **Evidencia:** cómo se demostró; si hubo una duda abierta, cómo se resolvió.
3. **Lo que no estaba roto:** por qué un componente vecino funcionaba bien.
4. **Ejecución mental:** «¿qué devuelve `f(x)`?» con entradas reales del cambio, casos límite incluidos.
5. **Decisiones de diseño:** por qué esta firma, esta capa, sin dependencia nueva…
6. **Efectos colaterales:** qué más cambia de comportamiento, quién más recibe el valor.
7. **Tests:** qué cubren, qué trampa evitan (por qué fijan una TZ concreta, qué los hacía pasar en falso).
8. **Interacción con otras ramas o PRs.**

- **Solo hechos verificados.** Cada pregunta se apoya en algo que has comprobado en el código, el diff, los datos o la conversación. Si una depende de una inferencia, avísamelo en el chat al entregar, diciendo cuál y por qué.
- **Código inline con `<code>`.** Si una pregunta necesita más de 3 líneas de código, es una mala pregunta.
- **Cada pregunta lleva su explicación**, que se muestra al responder: por qué la correcta lo es, con el dato verificable (`fichero:línea`, el valor, el log). Si explica por qué tienta un distractor, mejor.

### Opciones sin pistas

La respuesta tiene que salir de entender el cambio, no de leer la forma de las opciones. El fallo típico es que la correcta sea la más larga y elaborada (mecanismo + consecuencia + matiz) frente a tres distractores de media línea: se acierta sin saber nada.

- **La opción afirma, la explicación demuestra.** La correcta dice lo justo para ser cierta y distinguible; el «porque…, además…, por eso…» va a `why`. Si al recortarla deja de distinguirse, el problema está en los distractores, no en ella.
- **Misma longitud y mismo nivel de detalle en las cuatro.** Si la correcta lleva un `<code>`, un valor concreto o un mecanismo, los distractores también. Un distractor desnudo («Porque CI corre en us-east-1») al lado de una correcta con causa y efecto es una pista.
- **Misma forma gramatical**: si una empieza por «Porque…», todas; si una es un valor, todas son valores del mismo tipo y formato.
- **Sin muletillas que delaten**: nada de absolutos solo en los distractores (siempre, nunca, solo) ni matices solo en la correcta (cerca de, a veces, en ese caso). La correcta no repite más palabras del enunciado que los distractores.
- **Distractores plausibles, hechos con material real del cambio**: funciones, constantes, ficheros y valores que existen en el diff, aplicados mal. Errores que alguien cometería de verdad — una explicación que fue hipótesis durante el debug, el comportamiento de antes del fix, la alternativa descartada —, no opciones absurdas. Sin «todas / ninguna de las anteriores».
- **Varía cuál es la larga.** En el conjunto, la correcta es la más larga en no más de ~3 de cada 10 preguntas y la más corta en alguna. El validador del paso 4 lo comprueba.

## 3. El HTML

- `~/src/html/<repo-name>/quiz-<slug>.html` (para un PR, `quiz-pr-<número>-<slug>.html`). Todas las reglas de **`## Output en HTML`** del `CLAUDE.md` global: estilo scriptorium, dark fijo, tipografía, autocontenido, iframe estrecho, `@media print` y **rotación a `archive/` antes de escribir**.
- Parte de la plantilla `~/.claude/quiz/template.html` y rellena sus marcadores `{{…}}`: eyebrow (`quiz · <repo> · <PR o tarea>`), título en forma de pregunta, lede (cuántas preguntas, sobre qué rama o PR, y que el orden de las opciones cambia al recargar), footer (fecha y de dónde salen las preguntas: commit, PR, evidencia). No toques el CSS ni el JS salvo para corregir un bug de la plantilla, y si lo haces, arréglalo también en el repo de dotfiles.
- Las preguntas van como JSON en `<script id="quiz-data">`: `questions[]` con `q`, `opts[]` (`{t, ok}`) y `why`, más `review` con lo que hay que releer si se falla mucho (`"el walkthrough walkthrough-pr-162-….html"` si existe; si no, `"el diff de la PR #162"` o similar). Escribe las opciones con la correcta en la posición que quieras: el JS baraja en cada carga y la marca solo va en `ok`.

Lo que ya hace la plantilla y no hay que reinventar: opciones como `<button type="button">` barajadas en cada carga; al responder, bloqueo de las cuatro, la correcta en verde `--accent`, la elegida en rojo si falla y la explicación desplegada con barra verde (acierto) o amarilla (fallo); barra sticky con `aciertos / respondidas · quedan N` y «empezar de nuevo»; mensaje final por porcentaje que remite a `review` en los tramos bajos; y en impresión, sin barra ni botón, con la correcta marcada y todas las explicaciones visibles para que el PDF sirva de chuleta.

## 4. Valida antes de entregar

```bash
python3 ~/.claude/quiz/check.py ~/src/html/<repo-name>/quiz-<slug>.html
```

Comprueba balanceo de etiquetas (documento y cada fragmento), marcadores sin rellenar, 10–12 preguntas con 4 opciones y una correcta, explicaciones presentes, sin `<pre>` y sin «todas las anteriores», y las pistas por longitud: la correcta no puede sacar más de un 15 % al distractor más largo, opciones de una misma pregunta sin desparejar más del doble, y el reparto de cuál es la más larga en el conjunto. Con errores, reescribe las opciones (casi siempre: recortar la correcta y pasar el detalle a `why`, o dar sustancia a los distractores) y vuelve a pasarlo hasta que dé `OK`. Las reglas de forma gramatical y muletillas no las mide: repásalas tú leyendo las cuatro opciones de cada pregunta seguidas.

## 5. Entrega

Dame en el chat la ruta local del fichero y, si alguna pregunta descansa en una inferencia no comprobada, cuál. No lo publiques como Artifact: compartirlo es decisión mía desde el visor.
