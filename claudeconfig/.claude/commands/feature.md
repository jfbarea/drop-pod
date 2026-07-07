Feature nueva en un repo ya existente.

Cada feature vive aislada en su propia carpeta `plan/<slug>/`. El fichero `plan/_active` contiene el slug de la feature en curso, y es lo que `builder`/`reviewer` leen para saber dónde trabajar.

1. Lee SPEC.md para el contexto global. Si `plan/_active` existe, lee también `plan/<activa>/PLAN.md` para saber qué hay en marcha.
2. Si te invocan desde /research con un hand-off, lee `plan/research/<slug>.md` (resumen destilado, NO el .html) y úsalo como input principal en lugar de preguntarme la feature desde cero.
3. Si no existe `plan/`, créalo. `plan/research/` es global; el resto vive por feature.
4. Si no hay hand-off de research, pregúntame qué feature quiero.
5. Elige un `<slug>` en kebab-case para la feature y crea su carpeta aislada:
   - `plan/<slug>/PLAN.md` — hitos numerados con slugs y criterios de aceptación verificables.
   - `plan/<slug>/_state.json` con `{"milestones": []}`.
   - `plan/<slug>/reviews/`.
   Escribe el slug en `plan/_active`. Enséñame el plan y espera OK.
6. Cuando dé OK, ciclo builder → reviewer hasta que el hito esté DONE.
7. NO toques otras features: solo trabajas dentro de `plan/<slug>/`.
