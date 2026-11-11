# =============================================================================
# construir_catalogo.R
#
# Lee el catálogo de series del SIE ya limpio (generado por el scraper de
# Python en el repo `siebanxico_scraper`: scrape_catalogo_estructuras.py ->
# scrape_series_por_estructura.py -> nose.py) y lo guarda como datos internos
# del paquete (R/sysdata.rda).
#
# A partir de esta versión, el catálogo llega como Parquet, ya con:
#   - fecha_inicio / fecha_fin como fechas reales (Date), no texto con
#     formatos distintos según periodicidad
#   - sector real de Banxico (ya no un alias de titulo_estructura)
#   - deduplicado y sin las series que no tienen ningún dato publicado en
#     el SIE (ver NEWS.md)
# así que este script YA NO reimplementa el parseo de fechas ni la limpieza
# de texto -- solo adapta nombres de columna y arma titulo_completo.
#
# Cómo usarlo:
#   1. Copia catalogo_series_sie_final.parquet (de siebanxico_scraper/) a
#      data-raw/ (o ajusta la ruta abajo)
#   2. Abre el proyecto en RStudio
#   3. Ejecuta este script completo: source("data-raw/construir_catalogo.R")
#   4. Confirma que R/sysdata.rda se actualizó
#   5. NO hagas commit de R/sysdata.rda (está en .gitignore)
#
# Requiere el paquete 'arrow' instalado (solo para este script de
# construcción -- no es dependencia del paquete instalado, no hace falta
# declararlo en DESCRIPTION).
# =============================================================================

library(arrow)
library(dplyr)
library(stringr)

# ── 1. Leer el Parquet -------------------------------------------------------

ruta_parquet <- "data-raw/catalogo_series_sie_final.parquet"

if (!file.exists(ruta_parquet)) {
  stop(
    "No se encontró el Parquet en '", ruta_parquet, "'.\n",
    "Cópialo desde siebanxico_scraper/catalogo_series_sie_final.parquet, ",
    "o ajusta la variable 'ruta_parquet'."
  )
}

message("Leyendo ", ruta_parquet, " ...")
raw <- arrow::read_parquet(ruta_parquet) %>%
  mutate(across(where(is.factor), as.character))   # columnas category -> character
message("  Filas leídas: ", nrow(raw))


# ── 2. Adaptar nombres de columna y construir titulo_completo ---------------

catalogo_series_sie <- raw %>%
  rename(
    titulo_estructura = estructura,
    frecuencia         = periodicidad
  ) %>%
  mutate(
    fecha_inicio = as.Date(fecha_inicio),
    fecha_fin    = as.Date(fecha_fin),
    # Título completo: combina estructura + serie para series con títulos
    # ambiguos (ej. "3.1 a 3.5" -> "Inflación General - 3.1 a 3.5")
    titulo_completo = if_else(
      str_detect(titulo_serie, "^[0-9]") |               # empieza con número
      str_length(titulo_serie) <= 20,                    # o es muy corto
      str_c(titulo_estructura, " - ", titulo_serie),
      titulo_serie                                       # si ya es descriptivo, déjalo
    )
  ) %>%
  select(
    codigo_serie,
    titulo_serie,
    titulo_completo,
    titulo_estructura,
    sector,
    frecuencia,
    tipo_cifra,
    unidad,
    fecha_inicio,
    fecha_fin
  ) %>%
  arrange(titulo_estructura, codigo_serie) %>%
  # Una fila por serie: el paquete indexa por codigo_serie (get_sie_series(),
  # get_sie_series_multiple()) y asume una sola fila por clave. Cuando una
  # clave aparece en más de un sector/estructura (poco común, ver NEWS.md),
  # se queda con la primera tras el arrange() anterior -- fecha_inicio,
  # fecha_fin, frecuencia, tipo_cifra y unidad son iguales entre esas filas
  # duplicadas; solo sector/estructura/titulo pueden variar.
  distinct(codigo_serie, .keep_all = TRUE)

message("  Series únicas en el catálogo: ", nrow(catalogo_series_sie))
message("  Estructuras:                  ", length(unique(catalogo_series_sie$titulo_estructura)))
message("  Sectores:                     ", length(unique(catalogo_series_sie$sector)))
message("  Rango de fechas inicio:       ",
        format(min(catalogo_series_sie$fecha_inicio, na.rm = TRUE)), " - ",
        format(max(catalogo_series_sie$fecha_inicio, na.rm = TRUE)))
message("  Series sin fecha_inicio/fecha_fin: ",
        sum(is.na(catalogo_series_sie$fecha_inicio) | is.na(catalogo_series_sie$fecha_fin)))


# ── 3. Guardar como datos internos del paquete --------------------------------

usethis::use_data(catalogo_series_sie, internal = TRUE, overwrite = TRUE)
message("\nR/sysdata.rda actualizado correctamente.")
message("Recuerda NO hacer commit de ese archivo (ya está en .gitignore).")
