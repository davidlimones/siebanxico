# Catálogo interno del SIE

Este directorio contiene los scripts utilizados para construir el catálogo
interno de series (`R/sysdata.rda`).

## ¿Por qué no está disponible públicamente?

El catálogo fue generado recorriendo la estructura temática del
[Portal del SIE](https://www.banxico.org.mx/SIE/) de forma programática.
Para respetar los términos de uso del portal y evitar la distribución masiva
de su contenido, **el catálogo no se incluye en el repositorio público**.

El archivo `R/sysdata.rda` está explícitamente excluido mediante `.gitignore`.

## Estructura del catálogo

El objeto `catalogo_series_sie` es un data frame con las siguientes columnas:

| Columna             | Tipo       | Descripción                              |
|---------------------|------------|------------------------------------------|
| `codigo_serie`      | character  | Clave única de la serie (ej. `SF43718`)  |
| `titulo_serie`      | character  | Título descriptivo de la serie           |
| `titulo_estructura` | character  | Nombre de la estructura temática         |
| `sector`            | character  | Sector económico                         |
| `frecuencia`        | character  | Frecuencia de publicación                |
| `unidad`            | character  | Unidad de medida                         |
| `fecha_inicio`      | character  | Primera fecha disponible (`YYYY-MM-DD`)  |
| `fecha_fin`         | character  | Última fecha disponible (`YYYY-MM-DD`)   |

## Cómo reconstruir el catálogo

Si deseas construir tu propio catálogo, puedes explorar la estructura del SIE
mediante la [API oficial](https://www.banxico.org.mx/SieAPIRest/service/v1/doc/catalogoSeries)
o navegando el portal. El punto de partida es el catálogo de estructuras:

```
GET https://www.banxico.org.mx/SieAPIRest/service/v1/series/{estructura}/datos/oportuno
```

Una vez construido el data frame con la estructura anterior, guárdalo como
datos internos del paquete:

```r
catalogo_series_sie <- <tu_data_frame>
usethis::use_data(catalogo_series_sie, internal = TRUE, overwrite = TRUE)
```

Esto genera `R/sysdata.rda`, que el paquete detecta automáticamente al
cargarse. Asegúrate de que el archivo **no quede en el control de versiones**
(ya está en `.gitignore`).

## Nota sobre las pausas

Si construyes el catálogo realizando múltiples peticiones al SIE,
**introduce pausas entre peticiones** (`Sys.sleep()`) para no saturar la API.
Se recomienda al menos 1–2 segundos entre peticiones individuales y 60 segundos
entre lotes grandes.
