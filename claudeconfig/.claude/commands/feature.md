Feature nueva en un repo ya existente. Implementa lo que la spec ya decidió.

Cada feature vive aislada en su propia carpeta `plan/<slug>/`. El fichero `plan/_active` contiene el slug de la feature en curso, y es lo que `builder`/`reviewer` leen para saber dónde trabajar.

**Requisito de entrada: una spec aprobada.** Este comando no decide qué se construye. Eso se hace en `/specs`.

1. Localiza `plan/specs/<slug>.md` con `status: APPROVED` para la feature pedida.
   - Si no existe ninguna, **para y dime que hay que pasar por `/specs`**. No te inventes el alcance ni me interrogues aquí sobre la feature.
   - Si existe pero está en `DRAFT` o `REVIEW`, dímelo y espera: la spec aún no está cerrada.
   - Si te insisto en seguir sin spec aprobada, es mi decisión: sigues, pero escribes en `PLAN.md` que se implementó sin spec y qué asumiste.
2. Lee `SPEC.md` para el contexto global y `plan/specs/<slug>.md` como input principal. Si `plan/_active` existe, lee también `plan/<activa>/PLAN.md` y el `status` de `plan/<activa>/_state.json` para saber qué hay en marcha.
3. Si no existe `plan/`, créalo. `plan/research/` y `plan/specs/` son globales; el resto vive por feature.
4. Antes de ponerte con el plan, comprueba si ya hay una PR abierta parecida: `gh pr list --state open --json number,title,headRefName,author,url` y compara título/rama con la feature pedida (si un título es ambiguo, mira su descripción con `gh pr view <n>`). Si hay solape, notifícamelo (número, título, autor, URL y en qué se parece) y espera mi decisión antes de crear nada. Si `gh` falla o no hay remote, dilo y sigue.
5. Crea la carpeta aislada de la feature, reusando el `<slug>` de la spec:
   - `plan/<slug>/PLAN.md` — hitos numerados con slugs y criterios de aceptación verificables, **derivados de los criterios de aceptación de la spec**. Cada criterio de la spec tiene que quedar cubierto por al menos un hito, y cada hito referencia los criterios que cierra. Si un criterio no encaja en ningún hito, dímelo antes de seguir.
   - `plan/<slug>/_state.json` con `{"status": "BUILDING", "milestones": [], "spec": "plan/specs/<slug>.md"}`.
   - `plan/<slug>/reviews/`.
   Escribe el slug en `plan/_active`.

   El plan se parte al ritmo al que yo puedo revisar, no al que tú puedes escribir:
   - **Hitos pequeños y verticales.** Cada hito cierra un comportamiento observable de punta a punta y cabe en un commit de unas 200 líneas de diff sin contar tests. Si estimas más, pártelo antes de enseñármelo. Un hito horizontal («toda la capa de datos») no vale: no se puede comprobar solo.
   - **El primer hito es de contratos** cuando la feature introduce tipos, firmas, esquemas o formatos nuevos: solo eso, sin implementación. Es lo más barato de revisar y lo más caro de cambiar después.
   - **Cada hito nombra sus tests** como ejemplos de comportamiento (entrada → resultado). Son lo primero que voy a leer al revisarlo.
   - **Propón qué hito me reservo yo**: el algoritmo delicado, el modelo de datos, el caso límite raro. Márcalo `autor: humano` en `PLAN.md`; el resto, `autor: agente`. Si te digo que ninguno, ninguno.

   Enséñame el plan y espera OK.
6. Cuando dé OK, avanza **un hito y para**. No encadenes hitos: mi atención es el cuello de botella, y código que no he revisado no es avance.
   - Hito `autor: agente`: ciclo builder → reviewer hasta que el hito esté DONE.
   - Hito `autor: humano`: no invoques `builder`. Anota el HEAD actual como `base_sha` del hito, dime que es mi turno y espera. Cuando te diga que está, anota `commit_sha`, ponlo en `READY_FOR_REVIEW` y lanza `reviewer`.
   - Con el hito DONE, dame la **guía de revisión** y espera mi OK antes de abrir el siguiente. Seis líneas, no un informe:
     ```
     Hito 03 — <slug> · <sha> · +N / −M (tests aparte: +T)
     Qué cambia: una línea
     Tests que leer primero: fichero — los casos que cubre
     Decisiones que la spec no fijaba: cuáles, o «ninguna»
     Dónde está el riesgo: fichero:línea — por qué un error ahí sale caro
     Reviewer: veredicto y sugerencias que quedan abiertas
     ```
     Sale de la `review_guide` del builder y del informe del reviewer. Si el diff se pasó de las 200 líneas, dilo en la primera línea.
   - Mi feedback sobre el hito va a su `review_feedback`, el hito vuelve a `PENDING` y se arregla en un commit nuevo.
   - Solo dejas de parar entre hitos si te lo pido explícitamente para esta feature.

   La spec es el contrato: si durante la implementación aparece algo que la spec no contempla o la contradice, **no lo decidas tú** — párame, dímelo, y lo resolvemos en `/specs` antes de continuar.
7. Estado de la feature (`status` en `plan/<slug>/_state.json`), separado del estado por hito:
   - `BUILDING` — hay hitos por avanzar; el ciclo builder → reviewer está en marcha.
   - `HUMAN_REVIEW` — todos los hitos están DONE y la feature espera mi revisión antes de abrirse al equipo. Ponlo tú al cerrar el último hito, comprueba criterio por criterio que la spec queda satisfecha, genera el walkthrough para el scriptorium con el diff completo de la feature (instrucciones en `walkthrough.md`, junto a este fichero) y avísame de que la feature queda pendiente de mi revisión. En este estado NO avances hitos, NO abras PR y NO desactives la feature.
   - `DONE` — le he dado el visto bueno tras mi revisión; a partir de ahí la revisión pasa al equipo (PR).
   Mi feedback durante `HUMAN_REVIEW` se convierte en hitos nuevos PENDING en PLAN.md y el status vuelve a `BUILDING`.
8. NO toques otras features: solo trabajas dentro de `plan/<slug>/`.
