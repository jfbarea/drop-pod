# Review — hito 1: delete-endpoint

## Ronda 2

### Veredicto: APPROVED

El bloqueante de la ronda 1 (lost-update en el mapping entre `/share` y `/delete`
concurrentes) queda corregido y verificado de forma independiente, reproduciendo el
mismo repro exacto de la ronda 1 más un segundo escenario (dos `/delete` concurrentes)
contra una copia parcheada del módulo real.

#### (1) ¿`update_mapping` cubre TODOS los ciclos leer-modificar-escribir?

Sí. `grep -n "save_mapping\|load_mapping\|update_mapping"` sobre el fichero final
confirma que `save_mapping` solo se invoca una vez en todo el fichero, dentro de
`update_mapping` (`macos/scriptorium-share.py:86-94`, bajo `with mapping_lock:`). Los
otros dos usos de `load_mapping()` sueltos son de solo lectura y no escriben:
`do_GET`/`GET /shares` (línea 239, respuesta de solo lectura) y la lectura de
`existing_url` en `_handle_share` (línea 278, solo texto del prompt, ver punto 3). Los
dos únicos mutadores del mapping —`_set_share` en `_handle_share` (línea ~289-293) y
`_drop` en `_handle_delete` (línea ~335-337)— pasan por `update_mapping`, que hace
`load → mutator(mapping) → save` entero dentro del lock. No queda ningún
`save_mapping` fuera de `update_mapping`.

#### (2) ¿Riesgo de deadlock entre `mapping_lock` y `publish_lock`?

No. Solo hay un único orden de adquisición posible: `_handle_share` adquiere
`publish_lock` primero (con `acquire(blocking=False)`, no bloqueante — nunca puede
quedarse esperando) y, únicamente si lo consigue, entra en `update_mapping`, que
adquiere `mapping_lock` **anidado dentro** de `publish_lock` ya poseído. `_handle_delete`
nunca toca `publish_lock` en ningún punto — solo adquiere `mapping_lock` de forma
aislada vía `update_mapping`. Para que hubiera deadlock harían falta dos hilos
adquiriendo los mismos dos locks en órdenes inversos; aquí solo existe un camino de
adquisición (`publish_lock` → `mapping_lock`) y ningún camino inverso
(`mapping_lock` → `publish_lock`), así que no hay ciclo posible. Tampoco hay
reentrada: `update_mapping` se invoca como máximo una vez por petición, nunca
anidado dentro de otra adquisición de `mapping_lock`.

#### (3) Lectura previa de `existing_url` sin lock — ¿algo peor que una URL obsoleta en el prompt?

Es un riesgo real pero de bajo impacto y preexistente al diseño de `/share`, no algo
que este hito o su fix introduzcan. Escenario: se borra `docX.html` (vía `/delete`,
que libera su nombre) y se **recrea** un fichero nuevo con el mismo path relativo
mientras un `/share` de ese mismo `docX.html` sigue en curso (30-180 s dentro de
`publish()`). El `existing_url` leído al principio (`U1`, del doc original) se le pasa
a Claude para que "actualice en sitio" — pero el contenido que Claude realmente lee
del disco en el momento de ejecutar `Read` es el del fichero **recreado**, no el
original. Resultado: el artifact en `U1` termina mostrando el contenido del fichero
nuevo, y `_set_share` (ya con el fix, mapping fresco) deja correctamente
`docX.html -> U1` — consistente con "lo que hay ahora en ese path tiene esa URL",
aunque `U1` fuera originalmente la URL de un documento distinto y ya borrado.

Esto no es peor que el caso más simple que ya existía **antes** de este hito
(alguien edita el contenido de `docX.html` mientras un `/share` de ese mismo doc está
en curso: Claude publica lo que esté en disco en el momento de leer, no lo que había
al hacer clic) — el borrado+recreación solo es una vía adicional para el mismo tipo de
staleness de contenido, no una categoría nueva de fallo, y el `mapping_lock` no puede
arreglarlo porque protege los metadatos (el JSON del mapping), no el contenido del
`.html` en disco durante los 30-180 s que dura la sesión de Claude. Arreglarlo de
verdad requeriría fijar la identidad del fichero al inicio (p. ej. comprobar
inode/mtime antes de que Claude lo lea, o pasarle el contenido ya leído en vez de un
path) — alcance mayor que el de este hito, que iba explícitamente sobre la
corrupción del mapping. Lo dejo como riesgo documentado, no como bloqueante: la
ventana de exploit requiere borrar y recrear el MISMO path relativo mientras un share
de ese path concreto está en curso, un caso de uso muy improbable en el flujo real de
un solo usuario.

#### (4) Repro del escenario original + nuevo escenario delete-vs-delete

Repetido el harness de la ronda 1 (copia parcheada del `.py` real con
`BASE_DIR`/`TRASH_DIR`/`PORT` redirigidos a un directorio temporal aislado y
`publish()` sustituida por `time.sleep(3)` + URL fake — cero cambios sobre
`_handle_share`/`_handle_delete`/`update_mapping`, que corren tal cual):

- **`/share docA` concurrente con `/delete docB`** (el repro exacto de la ronda 1):
  ```
  mapping final = {
    "docA.html": {"sharedAt": "...", "url": "https://fake.example/test-artifact"},
    "docC.html": {... vieja ...},
    "docD.html": {... vieja ...}
  }
  ```
  `docB.html` queda ausente del mapping (no resucitada) y presente en el `TRASH_DIR`
  de prueba. Antes del fix esto resucitaba la entrada vieja de `docB`; ahora no.

- **Dos `/delete` concurrentes** (`docC` y `docD` en paralelo, escenario nuevo pedido
  en esta ronda): ambos devuelven 200, y el mapping final solo conserva `docA` — ni
  `docC` ni `docD` reaparecen, ninguna escritura se pierde entre las dos.

Limpieza: proceso del bridge de prueba detenido, directorio temporal de la race
borrado por completo; no se tocó `~/src/html` real, `~/.Trash` real, ni se disparó
ningún `/share` contra el bridge de producción ni se publicó ningún artifact.

### Otras verificaciones de esta ronda

- `grep` confirma que `resolve_delete_path`, `is_mapping_file` y `move_to_trash` no
  cambiaron respecto a la ronda 1 (el diff de esta ronda toca solo `mapping_lock`,
  `update_mapping` y los dos métodos `_handle_share`/`_handle_delete` en la parte de
  mapping) — no hace falta repetir todas las pruebas de symlinks/traversal de la
  ronda 1, siguen aplicando sin cambios.
- La corrección de la nota sobre el symlink roto (404 en vez de 400, ya señalada como
  no-bug en la ronda 1) quedó reflejada en `_state.json` sin tocar código, como se
  pidió.
- `bash test.sh` → 116 pasados, 0 fallidos, 0 omitidos (repetido de forma independiente
  en esta ronda).

## Bloqueantes

Ninguno.

## Sugerencias

Ninguna nueva sobre el código; las de la ronda 1 (documentación del 404 de symlink
roto) ya quedaron resueltas.

## Riesgos

- **Staleness de contenido durante una publicación larga** (punto 3 de arriba):
  borrar+recrear el mismo path mientras hay un `/share` de ese path en curso puede
  hacer que un artifact URL termine mostrando contenido de un documento distinto al
  que el usuario creía estar compartiendo. Baja probabilidad en uso normal
  (single-user), documentado aquí para no perderlo de vista si en el futuro se
  añaden acciones en lote o multi-usuario sobre el mismo catálogo.
- Se mantienen los riesgos ya documentados en la review del hito `bridge`
  (alcance de `Write` + `CLAUDE_CWD=~/drop-pod` en la sesión de Claude); no aplican a
  este endpoint, que no lanza sesiones de Claude.
