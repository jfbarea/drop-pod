Operación rápida. Sin plan, sin estado.

Comportamiento:
- Si es una pregunta o consulta: responde directamente, no toques archivos.
- Si es un bugfix o cambio pequeño: implementa, haz commit con formato `fix(<scope>): <resumen>`, resúmeme el diff y genera el walkthrough para el scriptorium (instrucciones en `walkthrough.md`, junto a este fichero).
- Solo invoca al subagente `reviewer` si:
  (a) el cambio toca más de 3 archivos, o
  (b) yo te lo pido explícitamente con "revísalo".

No crees `plan/`, no toques `_state.json`, no escribas SPEC.md.
