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

Con el resultado del built-in en la mano, genera el informe en `~/src/html/<repo-name>/code-review-<slug>.html` (para un PR, `code-review-pr-<número>-<slug>.html`), siguiendo TODAS las reglas de HTML del `CLAUDE.md` global: estilo scriptorium, dark fijo, tipografía, SVG para cualquier diagrama, bloque `@media print`, **rotación a `archive/` antes de escribir**, y que se vea bien embebido en un iframe estrecho.

Genera el informe **también cuando la review sale limpia**: una review sin hallazgos, archivada y con su alcance escrito, también es información.

El HTML es un acta del resultado, no una segunda review: no añadas findings, severidades ni conclusiones que el built-in no haya dado. Para incrustar los hunks, lee el diff del mismo ámbito que revisó el motor.

Estructura:

1. **Cabecera**: ámbito revisado (PR con título, autor, ramas, estado y enlace, o el rango del diff local), fecha, ficheros y líneas tocadas, y el veredicto en una frase.
2. **Findings**, uno por bloque, ordenados de más grave a menos. Cada uno con: severidad y confianza visibles usando los colores semánticos (rojo crítico, amarillo warning, azul info) sobre los tokens del scriptorium, `fichero:línea` enlazado, el hunk relevante en un `pre`, con qué entrada o estado concreto falla, y el fix propuesto.
3. **Alcance de la review**: qué cubrió el motor y qué queda explícitamente fuera (build, typecheck y tests los cubre CI, no esta review). Sin esto el informe se lee como "está todo bien" cuando en realidad dice "esto es lo que se miró".
4. **Descartados**, si el motor los expuso: qué se marcó y por qué no sobrevivió. Es lo que hace la review auditable.

Si la review corrió con `--fix`, el informe documenta los findings **y** lo que se aplicó al working tree, distinguiendo una cosa de la otra.

Al terminar, dime la ruta del fichero (el scriptorium lo cataloga solo).
