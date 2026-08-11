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
2. Genera el HTML en `~/src/html/<repo-name>/` con nombre `walkthrough-<slug>.html` (para un PR, `walkthrough-pr-<número>-<slug>.html`), siguiendo TODAS las reglas de HTML del CLAUDE.md global: estilo scriptorium, dark fijo, tipografía, SVG para diagramas, bloque `@media print`, rotación a `archive/` antes de escribir, compatible con iframe.
3. Estructura diff a diff, exhaustiva:
   - Cada hunk se muestra (diff resaltado o antes/después) seguido de su explicación: qué hace, por qué se hizo así, y cómo encaja con el resto.
   - Nada se omite por "menor": renombres, imports, config, tests — todo lo que aparece en el diff se explica.
   - Incluye el contexto que tendría el autor: decisiones tomadas, alternativas descartadas, invariantes que el cambio respeta. Para un PR, apóyate en su descripción y en los mensajes de commit, y abre el documento con una cabecera del PR (título, autor, ramas, enlace, estado).
4. Criterio de calidad: después de leerlo debo poder defender ese código en una review como si fuera mío. Un resumen de alto nivel por features o por ficheros NO vale.
5. Al terminar, dime la ruta del fichero generado (el scriptorium lo cataloga solo).
