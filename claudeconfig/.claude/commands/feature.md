Feature nueva en un repo ya existente.

Cada feature vive aislada en su propia carpeta `plan/<slug>/`. El fichero `plan/_active` contiene el slug de la feature en curso, y es lo que `builder`/`reviewer` leen para saber dónde trabajar.

1. Lee SPEC.md para el contexto global. Si `plan/_active` existe, lee también `plan/<activa>/PLAN.md` y el `status` de `plan/<activa>/_state.json` para saber qué hay en marcha.
2. Si te invocan desde /research con un hand-off, lee `plan/research/<slug>.md` (resumen destilado, NO el .html) y úsalo como input principal en lugar de preguntarme la feature desde cero.
3. Si no existe `plan/`, créalo. `plan/research/` es global; el resto vive por feature.
4. Si no hay hand-off de research, pregúntame qué feature quiero.
5. Antes de ponerte con el plan, comprueba si ya hay una PR abierta parecida: `gh pr list --state open --json number,title,headRefName,author,url` y compara título/rama con la feature pedida (si un título es ambiguo, mira su descripción con `gh pr view <n>`). Si hay solape, notifícamelo (número, título, autor, URL y en qué se parece) y espera mi decisión antes de crear nada. Si `gh` falla o no hay remote, dilo y sigue.
6. Elige un `<slug>` en kebab-case para la feature y crea su carpeta aislada:
   - `plan/<slug>/PLAN.md` — hitos numerados con slugs y criterios de aceptación verificables.
   - `plan/<slug>/_state.json` con `{"status": "BUILDING", "milestones": []}`.
   - `plan/<slug>/reviews/`.
   Escribe el slug en `plan/_active`. Enséñame el plan y espera OK.
7. Cuando dé OK, ciclo builder → reviewer hasta que el hito esté DONE.
8. Estado de la feature (`status` en `plan/<slug>/_state.json`), separado del estado por hito:
   - `BUILDING` — hay hitos por avanzar; el ciclo builder → reviewer está en marcha.
   - `HUMAN_REVIEW` — todos los hitos están DONE y la feature espera mi revisión antes de abrirse al equipo. Ponlo tú al cerrar el último hito, genera el walkthrough para el scriptorium con el diff completo de la feature (instrucciones en `walkthrough.md`, junto a este fichero) y avísame de que la feature queda pendiente de mi revisión. En este estado NO avances hitos, NO abras PR y NO desactives la feature.
   - `DONE` — le he dado el visto bueno tras mi revisión; a partir de ahí la revisión pasa al equipo (PR).
   Mi feedback durante `HUMAN_REVIEW` se convierte en hitos nuevos PENDING en PLAN.md y el status vuelve a `BUILDING`.
9. NO toques otras features: solo trabajas dentro de `plan/<slug>/`.
