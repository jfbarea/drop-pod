---
description: Commitea los cambios sin commitear en commits atómicos y legibles.
argument-hint: [scope o instrucciones opcionales]
allowed-tools: Read, Grep, Glob, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git reset:*), Bash(git restore:*), Bash(git apply:*), Edit, Write
---

Commitea TODOS los cambios sin commitear, agrupados en commits atómicos y legibles.

Reglas estrictas:
- **NUNCA hagas `git push`.** Solo commits locales; el push lo hace el usuario a mano.
- **No alteres la lógica de ningún fichero.** `Edit`/`Write` solo se permiten para la técnica de *strip & restore* al aislar hunks de un fichero que mezcla varios asuntos; el contenido final del working tree debe quedar idéntico al estado inicial. Si tocas algo para aislar, restáuralo.
- **Un commit = un cambio lógico.** Si un fichero mezcla asuntos distintos, sepáralos por hunks en commits diferentes. No agrupes cosas no relacionadas.
- **El árbol debe quedar coherente en cada commit**: si el proyecto tiene tests/build rápidos, deberían pasar en cada punto.
- No saltes hooks (`--no-verify`, `--no-gpg-sign`).
- Respeta las reglas de commits del `CLAUDE.md` del proyecto si existen (formato, atomicidad, trailers).

Formato de mensaje:
- `tipo(scope): resumen` en imperativo y conciso (feat, fix, chore, docs, refactor, test…).
- Cuerpo opcional (líneas a ~72 cols) explicando el **porqué** cuando no sea obvio.
- Legible: que al leer `git log --oneline` se entienda la historia sin abrir los diffs.

Flujo:
1. `git status` y `git diff` (más `git diff --cached` y los untracked) para entender TODO lo pendiente.
2. Diseña el plan de commits: lista las unidades lógicas y marca qué ficheros mezclan asuntos.
3. Por cada unidad: stagea solo lo suyo —whole-file si el fichero es de un solo asunto; si está mezclado, aísla por hunks con `git apply --cached` o *strip & restore*— y commitea.
4. Verifica entre commits que el `git diff --cached` es exactamente lo esperado antes de cada commit.
5. Al terminar: muestra `git log --oneline` de lo creado y confirma que `git status` queda limpio. **No hagas push.**

Si el working tree no tiene cambios, dilo y no hagas nada.

Instrucciones/scope opcionales del usuario: $ARGUMENTS
