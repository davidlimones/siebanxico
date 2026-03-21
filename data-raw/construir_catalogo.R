# =============================================================================
# construir_catalogo.R
#
# Lee el CSV con el catálogo scrapeado del SIE, lo limpia y lo guarda como
# datos internos del paquete (R/sysdata.rda).
#
# Cómo usarlo:
#   1. Coloca el CSV en data-raw/ (o ajusta la ruta abajo)
#   2. Abre el proyecto en RStudio
#   3. Ejecuta este script completo: source("data-raw/construir_catalogo.R")
#   4. Confirma que R/sysdata.rda se actualizó
#   5. NO hagas commit de R/sysdata.rda (está en .gitignore)
# =============================================================================

library(readr)
library(dplyr)
library(stringr)

# ── 1. Leer el CSV -----------------------------------------------------------

ruta_csv <- "data-raw/catalogo_series_sie.csv"   # ajusta si tu archivo está en otro lado

if (!file.exists(ruta_csv)) {
  stop(
    "No se encontró el CSV en '", ruta_csv, "'.\n",
    "Coloca el archivo ahí o ajusta la variable 'ruta_csv'."
  )
}

message("Leyendo ", ruta_csv, " ...")
raw <- read_csv(
  ruta_csv,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
message("  Filas leídas: ", nrow(raw))


# ── 2. Limpiar -----------------------------------------------------------

limpiar <- function(x) str_trim(str_remove(x, "\\.\\s*$"))

# El SIE usa tres formatos de fecha según la periodicidad de la serie:
#   1. "02/01/1996"     → series diarias        → primer día exacto
#   2. "Ene 1977"       → series mensuales      → primer día del mes
#   3. "Ene-Mar 2000"   → series trimestrales   → primer día del trimestre
parsear_fecha_sie <- function(x) {
  meses <- c(Ene=1, Feb=2, Mar=3, Abr=4, May=5, Jun=6,
             Jul=7, Ago=8, Sep=9, Oct=10, Nov=11, Dic=12)

  resultado <- as.Date(rep(NA, length(x)))

  # Formato 1: DD/MM/YYYY
  mask1 <- str_detect(x, "^\\d{1,2}/\\d{1,2}/\\d{4}$")
  resultado[mask1] <- as.Date(x[mask1], "%d/%m/%Y")

  # Formato 2: "Mes AAAA"  (ej. "Ene 1977")
  mask2 <- str_detect(x, "^[A-Za-z]{3} \\d{4}$")
  if (any(mask2, na.rm = TRUE)) {
    partes  <- str_match(x[mask2], "^([A-Za-z]{3}) (\\d{4})$")
    mes_num <- meses[partes[, 2]]
    resultado[mask2] <- as.Date(
      paste(partes[, 3], str_pad(mes_num, 2, pad = "0"), "01", sep = "-")
    )
  }

  # Formato 3: "Mes-Mes AAAA"  (ej. "Ene-Mar 2000", "Oct-Dic 1979")
  mask3 <- str_detect(x, "^[A-Za-z]{3}-[A-Za-z]{3} \\d{4}$")
  if (any(mask3, na.rm = TRUE)) {
    partes  <- str_match(x[mask3], "^([A-Za-z]{3})-[A-Za-z]{3} (\\d{4})$")
    mes_num <- meses[partes[, 2]]
    resultado[mask3] <- as.Date(
      paste(partes[, 3], str_pad(mes_num, 2, pad = "0"), "01", sep = "-")
    )
  }

  resultado
}

catalogo_series_sie <- raw %>%
  rename(titulo_estructura = estructura) %>%
  mutate(
    across(everything(), limpiar),                        # quita puntos finales
    fecha_inicio = parsear_fecha_sie(fecha_inicio),
    fecha_fin    = parsear_fecha_sie(fecha_fin),
    sector       = titulo_estructura,                     # alias para buscar_por_sector()
    # Título completo: combina estructura + serie para series con títulos ambiguos
    # (ej. "3.1 a 3.5" → "Inflación General — 3.1 a 3.5")
    titulo_completo = if_else(
      str_detect(titulo_serie, "^[0-9]") |               # empieza con número
      str_length(titulo_serie) <= 20,                    # o es muy corto
      str_c(titulo_estructura, " — ", titulo_serie),
      titulo_serie                                       # si ya es descriptivo, déjalo
    )
  ) %>%
  select(
    codigo_serie,
    titulo_serie,
    titulo_completo,
    titulo_estructura,
    sector,
    frecuencia  = periodicidad,
    tipo_cifra,
    unidad,
    fecha_inicio,
    fecha_fin
  ) %>%
  distinct(codigo_serie, .keep_all = TRUE) %>%           # elimina duplicados por clave
  arrange(titulo_estructura, codigo_serie)

message("  Series únicas en el catálogo: ", nrow(catalogo_series_sie))
message("  Estructuras:                  ", length(unique(catalogo_series_sie$titulo_estructura)))
message("  Rango de fechas inicio:       ",
        format(min(catalogo_series_sie$fecha_inicio, na.rm = TRUE)), " — ",
        format(max(catalogo_series_sie$fecha_inicio, na.rm = TRUE)))


# ── 3. Guardar como datos internos del paquete --------------------------------

usethis::use_data(catalogo_series_sie, internal = TRUE, overwrite = TRUE)
message("\nR/sysdata.rda actualizado correctamente.")
message("Recuerda NO hacer commit de ese archivo (ya está en .gitignore).")
