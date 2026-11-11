# Catálogo interno del SIE

Este directorio contiene los scripts utilizados para construir el catálogo
interno de series (`R/sysdata.rda`).

## ¿Por qué no está disponible públicamente?

El catálogo fue generado recorriendo la estructura temática del
[Portal del SIE](https://www.banxico.org.mx/SIE/) de forma programática.
Para respetar los términos de uso del portal y evitar la distribución masiva
de su contenido, **el catálogo no se incluye en el repositorio público**.

El archivo `R/sysdata.rda`, el CSV crudo (`data-raw/catalogo_series_sie.csv`)
y el Parquet limpio (`data-raw/catalogo_series_sie_final.parquet`) están
explícitamente excluidos mediante `.gitignore`.

## De dónde sale el catálogo

El catálogo se genera con el scraper de Python del repo `siebanxico_scraper`
(no forma parte de este repositorio): `scrape_catalogo_estructuras.py` ->
`scrape_series_por_estructura.py` -> `nose.py`. Ese último paso deja un
`catalogo_series_sie_final.parquet` ya limpio -- fechas parseadas por
periodicidad, sin duplicados, sin las series que no tienen ningún dato
publicado en el SIE (ver el `NEWS.md` de ese repo para el detalle). Copia
ese Parquet a `data-raw/` antes de correr `construir_catalogo.R`.

## Scraper y actualización semestral

El scraper está en `data-raw/scraper/` (Selenium + pandas). Los datos de
trabajo (CSV, logs y el entorno `venv_sie`) viven fuera del repo, en
`~/Documents/siebanxico_scraper` (se cambia con `SIE_DATA_DIR`).

```bash
caffeinate -i bash data-raw/scraper/run_actualizacion_catalogo.sh
```

El script scrapea, genera el Parquet, lo copia a `data-raw/`, reconstruye
`R/sysdata.rda`, corre las pruebas y reinstala el paquete si pasan. La tarea
programada (`com.davidlimones.actualizar_catalogo_sie.plist`) lo ejecuta el 1
de enero y el 1 de julio a las 2:00 AM.

## Estructura del catálogo

El objeto `catalogo_series_sie` es un data frame con las siguientes columnas:

| Columna             | Tipo       | Descripción                                             |
|---------------------|------------|----------------------------------------------------------|
| `codigo_serie`      | character  | Clave única de la serie (ej. `SF43718`)                  |
| `titulo_serie`      | character  | Título original de la fila en el portal del SIE          |
| `titulo_completo`   | character  | Título legible; combina estructura + serie cuando el título original es ambiguo (ej. "3.1 a 3.5") |
| `titulo_estructura` | character  | Nombre del cuadro/estructura temática del SIE             |
| `sector`            | character  | Sector económico real de Banxico (no un alias de `titulo_estructura`) |
| `frecuencia`        | character  | Periodicidad de publicación (`Diaria`, `Mensual`, `Trimestral`, etc.) |
| `tipo_cifra`        | character  | Naturaleza del dato (ej. `Saldos`, `Flujos`)              |
| `unidad`            | character  | Unidad de medida (ej. `Millones de Pesos`)                |
| `fecha_inicio`      | Date       | Primera fecha disponible                                  |
| `fecha_fin`         | Date       | Última fecha disponible                                   |

`fecha_inicio`/`fecha_fin` nunca vienen `NA`: las series sin ningún dato
publicado se descartan al construir el catálogo (no `get_sie_series()` de
todas formas no tendría qué consultar para ellas).

## Cómo reconstruir el catálogo

1. Corre el scraper de Python (`siebanxico_scraper`) para obtener un
   `catalogo_series_sie_final.parquet` actualizado.
2. Cópialo a `data-raw/catalogo_series_sie_final.parquet`.
3. Instala el paquete `arrow` si no lo tienes (`install.packages("arrow")`).
4. Corre `source("data-raw/construir_catalogo.R")` desde la raíz del
   proyecto en RStudio.
5. Confirma que `R/sysdata.rda` se actualizó y que
   `devtools::test()` / `testthat::test_dir("tests/testthat")` pasa,
   en particular `test-catalog-datos.R`.
6. NO hagas commit de `R/sysdata.rda` ni del Parquet (ya están en
   `.gitignore`).

## Nota sobre las pausas

Si actualizas el catálogo scrapeando el portal del SIE, **introduce pausas
entre peticiones** para no saturar el sitio. El scraper de Python ya hace
esto por defecto; si construyes tu propio catálogo por otra vía, se
recomienda al menos 1–2 segundos entre peticiones individuales y 60 segundos
entre lotes grandes.
