# Instrucciones globales — Fran

Aplican a todo repositorio. Escribe en español (commits, PRs, comentarios).

## Comentarios en el código

**El test, antes de escribir un comentario:** ¿esta información está en el código, o puede
estarlo? Si la respuesta es sí, el comentario no se escribe — se arregla el código. Si es no, el
comentario es obligatorio.

**Cero comentarios sobre el qué.** Nada que describa lo que hace la línea o el bloque siguiente.
Si un fragmento no se entiende sin comentario, refactoriza (renombra, extrae función, parte el
fichero) hasta que se entienda solo. Ningún comentario es coartada de un nombre malo.

**Solo estas cuatro clases, que el código no puede contener.** Lista cerrada:

1. **Hechos del entorno externo, con el dato concreto.** Versión que rompe, mensaje de error
   literal, comportamiento de una herramienta de terceros, nombre distinto de un paquete por
   distro. Ejemplo: `# Debian empaqueta bat como 'batcat'`.
2. **Alternativas descartadas.** Lo que se intentó y falló, y por qué.
3. **Invariantes no locales.** Orden obligatorio entre pasos, precondiciones del caller,
   acoplamientos a distancia.
4. **«Esto raro es a propósito».** Cuando el código parece un bug y no lo es.

**Formato:** una a tres líneas, pegadas a la línea que sorprende, no en bloque de cabecera, con el
dato verificable dentro (versión, número, error, flag).

**El porqué del diseño propio va al commit o a la PR**, no al código.

**Para un invariante que no puede romperse, escribe un test, no un comentario.**

**Sin banners ni separadores decorativos** (`# ── Helpers ──`) en código nuevo.

**No barras los comentarios existentes** al editar un fichero, salvo que contradigan al código
(entonces bórralos o corrígelos) o que el usuario lo pida.

**Docs de API pública** (docstrings, JSDoc, godoc) no cuentan como comentarios aquí: si el repo las
usa como convención, síguelas.

## Git

No hagas `git push` a `main`, `master`, `dev`, `develop`, `development` ni `alpha`. El push a ramas
protegidas lo hace el usuario a mano. Excepción: el repo `jfbarea/drop-pod`.
