Lee un issue de ClickUp por su URL e implementa la solución en el repo que corresponda.

Recibes la URL (o el ID) del issue en `$ARGUMENTS`. Si no hay argumento, pídeme la URL.

1. Extrae el `taskId` de la URL de ClickUp. Formatos habituales: `https://app.clickup.com/t/<taskId>`, `https://app.clickup.com/<teamId>/v/.../<taskId>`, o `.../<listId>/t/<taskId>`. Si recibes un ID suelto, úsalo tal cual.
2. Lee la tarea con la herramienta de "get task" del MCP de ClickUp (`mcp__claude_ai_ClickUp__*`). Si el MCP no está autenticado, dime que ejecute `/mcp` → "claude.ai ClickUp" y PARA. Resúmeme: título, descripción, estado, tags, Space/List/Folder y los criterios de aceptación que encuentres.
3. Infiere el repo destino entre los subdirectorios de `~/src/revel`: `driverevel-api`, `revel-app`, `revel-auth`, `revel-auto-transport`, `revel-erp`, `revel-web`. Usa como señales el Space/List/Folder, los tags, el título y la descripción (p.ej. menciones explícitas al repo, "web", "API", "auth", "ERP"…). Enséñame el repo inferido **con el porqué** y ESPERA mi confirmación antes de continuar. Si no lo tienes claro, pregúntame en vez de adivinar.
4. Una vez confirmado, trabaja dentro de ese repo (`~/src/revel/<repo>`).
5. Clasifica el issue como **feature** o **bug** a partir del contenido y los tags:
   - feature/mejora → sigue el flujo de `/feature`, usando el issue como input principal (no me preguntes la feature desde cero): título del issue → slug del hito; criterios de aceptación de la tarea → criterios de aceptación del hito.
   - bug → sigue el flujo de `/debug`, usando el síntoma/descripción del issue como punto de partida.
6. Respeta los gates de esos flujos: enséñame el hito/plan y espera mi OK antes de construir.
7. No comentes ni cambies el estado de la tarea en ClickUp salvo que te lo pida explícitamente. Al terminar, recuérdame el `taskId` por si quiero actualizarlo a mano.
