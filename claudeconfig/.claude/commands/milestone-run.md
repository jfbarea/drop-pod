Avanza un ciclo de hito (uso de bajo nivel, normalmente prefiere /feature).

1. Invoca el subagente `builder` para implementar el siguiente hito PENDING.
2. Cuando termine, invoca el subagente `reviewer` para revisar lo implementado.
3. Genera el walkthrough para el scriptorium con el diff del hito (instrucciones en `walkthrough.md`, junto a este fichero).
4. Resúmeme el veredicto y pregúntame si continúo con el siguiente hito.

NO ejecutes los dos en paralelo. Builder primero, reviewer después.
