Proyecto nuevo desde cero.

1. Pregúntame nombre del proyecto e idea en una frase si no te lo he dicho.
2. Invoca el subagente `architect` para producir SPEC.md, plan/PLAN.md y plan/_state.json.
3. Pausa y enséñame el plan. Espera mi OK antes de continuar.
4. Cuando dé OK, entra en bucle de hitos: builder → reviewer → siguiente.
5. Después de cada hito, pregúntame si sigo con el siguiente o paro.
6. Cuando paremos (o se acabe el plan), genera el walkthrough para el scriptorium con todo el código construido en la sesión (instrucciones en `walkthrough.md`, junto a este fichero).
