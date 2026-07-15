Walkthrough para el scriptorium: HTML que recorre el diff completo del trabajo recién terminado, diff a diff, explicándolo como si yo lo hubiera escrito.

Los comandos que cambian código (/feature, /debug, /quick, /clickup, /scaffold, /milestone-run) lo generan como último paso de su proceso. Si me invocas suelto, el ámbito es el diff del working tree más los commits locales frente a la rama base; si es ambiguo, pregúntame.

1. Delimita el diff a cubrir: todo lo que ha cambiado durante el proceso (commits creados + working tree), no solo el último cambio. Según el caso: `git diff <base>...HEAD`, `git diff HEAD`, o ambos.
2. Genera el HTML en `~/src/html/<repo-name>/` con nombre `walkthrough-<slug>.html`, siguiendo TODAS las reglas de HTML del CLAUDE.md global: estilo scriptorium, dark fijo, tipografía, SVG para diagramas, bloque `@media print`, rotación a `archive/` antes de escribir, compatible con iframe.
3. Estructura diff a diff, exhaustiva:
   - Cada hunk se muestra (diff resaltado o antes/después) seguido de su explicación: qué hace, por qué se hizo así, y cómo encaja con el resto.
   - Nada se omite por "menor": renombres, imports, config, tests — todo lo que aparece en el diff se explica.
   - Incluye el contexto que tendría el autor: decisiones tomadas, alternativas descartadas, invariantes que el cambio respeta.
4. Criterio de calidad: después de leerlo debo poder defender ese código en una review como si fuera mío. Un resumen de alto nivel por features o por ficheros NO vale.
5. Al terminar, dime la ruta del fichero generado (el scriptorium lo cataloga solo).
