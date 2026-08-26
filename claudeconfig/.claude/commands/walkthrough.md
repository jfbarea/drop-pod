---
description: Walkthrough para el scriptorium — HTML que recorre un diff completo, diff a diff, explicándolo en detalle. Sin argumento cubre el trabajo recién terminado; con un PR, todos los diffs de ese PR.
argument-hint: [PR (número, URL o rama) — opcional]
---

Walkthrough para el scriptorium: HTML que recorre un diff completo, diff a diff, explicándolo como si yo lo hubiera escrito.

Los comandos que cambian código (/feature, /debug, /quick, /clickup, /scaffold, /milestone-run) lo generan como último paso de su proceso. Si me invocas suelto sin argumento, el ámbito es el diff del working tree más los commits locales frente a la rama base; si es ambiguo, pregúntame.

El PR (opcional): $ARGUMENTS

1. Delimita el diff a cubrir:
   - **Con PR** (número, URL o rama): resuélvelo con `gh pr view` y saca el diff completo con `gh pr diff`. Recoge también el contexto del PR: título, descripción, lista de commits (`gh pr view --json title,body,commits,baseRefName,headRefName,url`) y, si los hay, comentarios de review relevantes. Si es una URL de otro repo, usa `gh -R <owner>/<repo>` y toma ese repo como `<repo-name>`. Para explicar bien un hunk puedes necesitar más contexto del que da el diff: lee los ficheros completos en la versión head del PR (`gh api` / `git fetch` + `git show`), no asumas que el working tree local coincide.
   - **Sin PR**: todo lo que ha cambiado durante el proceso (commits creados + working tree), no solo el último cambio. Según el caso: `git diff <base>...HEAD`, `git diff HEAD`, o ambos.
2. Genera el HTML en `~/src/html/<repo-name>/` con nombre `walkthrough-<slug>.html` (para un PR, `walkthrough-pr-<número>-<slug>.html`).
3. La estructura y los componentes los fija la sección **`## Walkthroughs y code reviews en el scriptorium`** del `CLAUDE.md` global, y no se negocian aquí: esqueleto de ocho apartados en ese orden, el walkthrough en `<details>` colapsados con su tabla resumen y sus bandas `.groupbar`, el hunk antes que la prosa, el reflow separado del cambio real, y todas las reglas de `## Output en HTML` (estilo scriptorium, dark fijo, tipografía, SVG para diagramas, `@media print`, **rotación a `archive/` antes de escribir**, iframe estrecho).
   - **Un walkthrough suelto no es una review**, así que el esqueleto es el mismo pero se rellena distinto: el veredicto es una frase de qué consigue el cambio en conjunto; el tally cuenta ficheros y `+N / −M` en vez de severidades; el alcance dice qué diff se cubrió y qué queda fuera.
   - Los apartados de **hallazgos** y de **comentario propuesto para la PR** siguen ahí y dicen explícitamente que este documento no es una review y que no se ha juzgado el código. Si al leer el diff me sale algo de todas formas, ponlo ahí con su severidad y su confianza — y dime en el chat que lo has añadido.
4. Dentro del walkthrough, la exhaustividad manda:
   - Cada hunk se muestra seguido de su explicación: qué hace, por qué se hizo así, y cómo encaja con el resto.
   - Nada se omite por "menor": renombres, imports, config, tests — todo lo que aparece en el diff se explica.
   - Incluye el contexto que tendría el autor: decisiones tomadas, alternativas descartadas, invariantes que el cambio respeta. Para un PR, apóyate en su descripción y en los mensajes de commit.
5. Criterio de calidad: después de leerlo debo poder defender ese código en una review como si fuera mío. Un resumen de alto nivel por features o por ficheros NO vale.
6. Al terminar, dime la ruta del fichero generado (el scriptorium lo cataloga solo).
