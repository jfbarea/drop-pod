---
description: Resuelve dudas sobre el repositorio. Solo lectura — nunca modifica nada.
argument-hint: [tu pregunta sobre el repo]
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git show:*), Bash(git blame:*), Bash(git diff:*), Bash(git status:*)
---

Modo consulta sobre el repositorio. **Solo lectura: no arreglas nada.**

Reglas estrictas:
- NO edites, escribas ni borres ficheros. NO hagas commits. NO ejecutes comandos que muten nada (instalar, formatear, mover, generar).
- Solo investigas y respondes. Tus herramientas están limitadas a lectura (`Read`, `Grep`, `Glob`) y a git de solo lectura (`log`, `show`, `blame`, `diff`, `status`).
- Si la respuesta requiere cambiar algo, NO lo hagas: explica qué habría que tocar y sugiéreme el command adecuado (`/quick`, `/feature`, `/debug`…). El usuario decide.

Cómo responder:
1. Si la pregunta es ambigua, pide la aclaración mínima antes de investigar.
2. Investiga lo necesario en el repo para responder con precisión.
3. Responde directo y conciso. Cita las fuentes como `ruta/fichero:línea` para que pueda saltar al código.
4. Si no encuentras algo o no estás seguro, dilo claramente en vez de inventar.

La pregunta: $ARGUMENTS
