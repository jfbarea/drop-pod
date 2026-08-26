---
description: Code review con el motor built-in de Anthropic y el informe completo en el scriptorium.
argument-hint: "[igual que /code-review: target (PR, rama o path), nivel (low|medium|high|max), --comment, --fix] — todo opcional"
---

Code review con el motor de Anthropic más un informe HTML en el scriptorium. Este comando es un envoltorio: la review la hace el built-in, yo solo la documento.

Los argumentos (opcionales): $ARGUMENTS

## 1. Delega la review al built-in

Invoca con la herramienta `Skill` la skill **`code-review`** — la built-in de Anthropic, no este comando — pasándole `$ARGUMENTS` **tal cual, sin añadir ni quitar nada**. Sus argumentos son suyos (target, nivel de esfuerzo, `--comment`, `--fix`) y van en passthrough: así el día que Anthropic cambie o amplíe ese contrato, este comando lo hereda sin que haya que tocarlo.

Ese es el motor de la review. No repliques ni sobrescribas su criterio: ni su rúbrica de confianza, ni su filtrado de falsos positivos, ni las dimensiones que revisa. Lo que Anthropic mejore ahí es exactamente lo que quiero heredar sin mantener nada. Si te parece que le falta algo, dímelo al final en vez de improvisar tu propia review por encima.

Tres límites que sí pongo yo:

- **Nunca añadas `--comment` ni `--fix` por tu cuenta.** Uno publica en GitHub y el otro me toca el working tree; los dos son decisión mía. Si yo los he escrito en los argumentos, eso ya es mi autorización: pásalos y no me vuelvas a preguntar.
- Sin `--fix` no arregles nada, ni "de paso": el resultado es la review y su informe. Los fixes son otra petición.
- Si el built-in decide que **no procede revisar** (PR cerrado, en draft, cambio trivial, ya revisado antes), dime el motivo y termina ahí. No hay resultado que documentar y no quiero un HTML vacío.

## 2. Métemelo en el scriptorium

Con el resultado del built-in en la mano, genera el informe en `~/src/html/<repo-name>/code-review-<slug>.html` (para un PR, `code-review-pr-<número>-<slug>.html`).

La estructura y los componentes del documento los fija la sección **`## Walkthroughs y code reviews en el scriptorium`** del `CLAUDE.md` global, y no se negocian aquí: esqueleto de ocho apartados en ese orden, walkthrough en desplegables colapsados, hallazgos con severidad y confianza separadas, comentario de PR listo para pegar por hallazgo, verificaciones de anclaje contra el head, y las reglas de `## Output en HTML` (estilo scriptorium, dark fijo, tipografía, SVG, `@media print`, **rotación a `archive/` antes de escribir**, iframe estrecho). Este comando solo aporta el ámbito, el nombre del fichero y de dónde salen los hallazgos.

Genera el informe **también cuando la review sale limpia**: una review sin hallazgos, archivada y con su alcance escrito, también es información. En ese caso el tally va a cero, los apartados de hallazgos y de comentarios propuestos lo dicen explícitamente, y el peso del documento lo lleva el walkthrough más «comprobado y descartado».

El HTML es un acta del resultado, no una segunda review: no añadas findings, severidades ni conclusiones que el built-in no haya dado. Para incrustar los hunks, lee el diff del mismo ámbito que revisó el motor, y los ficheros completos en el head para verificar cada `fichero:línea`.

En el apartado de alcance, deja explícito que build, typecheck y tests los cubre CI y no esta review.

Si la review corrió con `--fix`, el informe documenta los findings **y** lo que se aplicó al working tree, distinguiendo una cosa de la otra, y la cabecera lo refleja.

Al terminar, dime la ruta del fichero (el scriptorium lo cataloga solo).
