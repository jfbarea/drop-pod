# CLAUDE.md

<!-- 
  Plantilla global para ~/src/CLAUDE.md.
  Claude Code carga este archivo automáticamente cuando trabajas en este directorio.
  Personaliza cada sección para tu proyecto concreto.
-->

## Contexto del proyecto

<!-- Describe brevemente qué hace este proyecto y por qué existe. -->

## Stack tecnológico

<!-- Lenguajes, frameworks, bases de datos, servicios externos. -->

## Convenciones de código

- Idioma del código y comentarios: **inglés**
- Idioma de docs, README y mensajes: **español**
- Commits: formato convencional (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, …)
- Commits atómicos: un cambio lógico por commit. Si hay varios cambios independientes, commits separados. El árbol debe compilar y los tests pasar en cada commit.
- Rama principal: `main`

<!-- Añade aquí linters, formatters y sus comandos. -->

## Comandos frecuentes

```bash
# Instalar dependencias
# ...

# Desarrollo
# ...

# Tests
# ...

# Build / lint
# ...
```

## Estructura del proyecto

<!--
  Árbol de directorios con una línea de contexto por carpeta importante.
  Ayuda a Claude a orientarse sin explorar el repo completo.
-->

## Lo que Claude NO debe hacer sin confirmación explícita

- Push a ramas protegidas (`main`, `production`)
- Modificar archivos de configuración de entornos productivos
- Ejecutar migraciones destructivas (`DROP`, `DELETE` sin `WHERE`, `db reset`)
- Publicar paquetes (`npm publish`, `cargo publish`, `twine upload`, …)
- Crear o destruir recursos cloud de pago

## Variables de entorno necesarias

<!--
  Lista las variables que necesita el proyecto (sin sus valores).
  Ejemplo:
  - DATABASE_URL
  - API_KEY_OPENAI
-->

## Contexto adicional

<!--
  Cualquier otra información que ayude a Claude: acceso a servicios,
  credenciales especiales, decisiones de arquitectura no obvias, etc.
-->
