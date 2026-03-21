# =============================================================================
# actualizar_catalogo.R
#
# Recorre el portal del SIE de Banxico para obtener el catálogo actualizado
# de series (nombre, clave, fechas, periodicidad, unidad).
#
# IMPORTANTE:
#   - Introduce pausas entre peticiones para no saturar los servidores.
#   - Guarda progreso parcial en data-raw/progreso/ para poder reanudar.
#   - El resultado final se guarda en data-raw/catalogo_series_sie.csv y
#     luego se convierte a R/sysdata.rda con construir_catalogo.R.
#
# Uso:
#   source("data-raw/actualizar_catalogo.R")
#
# Tiempo estimado: varias horas (depende del número de estructuras y la pausa).
# =============================================================================

library(httr)
library(jsonlite)
library(dplyr)
library(purrr)
library(readr)
library(stringr)

# ── Configuración -----------------------------------------------------------

TOKEN       <- getOption("siebanxico.token")   # set_sie_token() antes de correr
PAUSA_SERIE <- 1.5    # segundos entre peticiones de series individuales
PAUSA_BLOQUE <- 60    # segundos entre bloques grandes
RUTA_PROGRESO <- "data-raw/progreso"
RUTA_SALIDA   <- "data-raw/catalogo_series_sie.csv"

if (is.null(TOKEN) || nchar(trimws(TOKEN)) == 0) {
  stop("Configura tu token primero: set_sie_token('TU_TOKEN')")
}

dir.create(RUTA_PROGRESO, showWarnings = FALSE, recursive = TRUE)


# ── Helpers -----------------------------------------------------------------

headers_sie <- function() httr::add_headers("Bmx-Token" = TOKEN)

get_json <- function(url, pausa = PAUSA_SERIE) {
  res <- httr::GET(url, headers_sie(), httr::accept_json())
  Sys.sleep(pausa)

  codigo <- httr::status_code(res)
  if (codigo == 429L) {
    message("  [429] Limite alcanzado. Esperando 5 min...")
    Sys.sleep(300)
    res <- httr::GET(url, headers_sie(), httr::accept_json())
    Sys.sleep(pausa)
    codigo <- httr::status_code(res)
  }
  if (codigo != 200L) {
    warning("HTTP ", codigo, " en: ", url)
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"),
                       simplifyVector = FALSE),
    error = function(e) { warning("JSON inválido: ", url); NULL }
  )
}


# ── Paso 1: Obtener todas las estructuras temáticas del SIE ----------------
#
# La API del SIE expone un endpoint de catálogo de estructuras.
# Si este paso falla, puede ser porque la estructura de la URL cambió —
# en ese caso consulta: https://www.banxico.org.mx/SieAPIRest/service/v1/doc

message("=== Paso 1: Obteniendo lista de estructuras ===")

url_estructuras <- "https://www.banxico.org.mx/SieAPIRest/service/v1/series"
res_est <- get_json(url_estructuras)

# Intento alternativo: catálogo de estructuras con keyword vacía
if (is.null(res_est)) {
  message("  Intentando endpoint alternativo...")
  res_est <- get_json(paste0(url_estructuras, "?keyword="))
}

# Si ambos fallan, usa el catálogo existente para extraer las estructuras
if (is.null(res_est)) {
  message("  Usando catálogo existente para extraer estructuras...")
  if (file.exists(RUTA_SALIDA)) {
    cat_existente  <- read_csv(RUTA_SALIDA, col_types = cols(.default = "c"),
                               show_col_types = FALSE)
    estructuras_df <- data.frame(
      id     = unique(cat_existente$titulo_estructura),
      nombre = unique(cat_existente$titulo_estructura),
      stringsAsFactors = FALSE
    )
  } else {
    stop("No hay catálogo previo. Ejecuta el script manualmente con las ",
         "estructuras conocidas.")
  }
} else {
  series_raw  <- res_est$bmx$series %||% list()
  estructuras_df <- data.frame(
    id     = vapply(series_raw, function(x) x$idSerie  %||% "", character(1)),
    nombre = vapply(series_raw, function(x) x$titulo   %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

message("  Estructuras encontradas: ", nrow(estructuras_df))


# ── Paso 2: Para cada estructura, obtener sus series ----------------------

message("\n=== Paso 2: Descargando series por estructura ===")

# Archivo de progreso: guarda las estructuras ya procesadas
ruta_prog <- file.path(RUTA_PROGRESO, "estructuras_procesadas.rds")
procesadas <- if (file.exists(ruta_prog)) readRDS(ruta_prog) else character(0)

n_total <- nrow(estructuras_df)
resultados <- list()

for (i in seq_len(n_total)) {

  nombre_est <- estructuras_df$nombre[i]
  id_est     <- estructuras_df$id[i]

  if (id_est %in% procesadas) {
    message(sprintf("[%d/%d] Ya procesada: %s", i, n_total, nombre_est))
    next
  }

  message(sprintf("[%d/%d] Procesando: %s", i, n_total, nombre_est))

  # Obtener la lista de series de esta estructura
  # Banxico expone los datos "oportuno" (último dato) para listar series
  url_series <- glue::glue(
    "https://www.banxico.org.mx/SieAPIRest/service/v1/series/{id_est}/datos/oportuno"
  )

  datos <- get_json(url_series)
  if (is.null(datos)) {
    message("  [SKIP] No se pudieron obtener datos.")
    next
  }

  series <- datos$bmx$series %||% list()

  if (length(series) == 0) {
    message("  [SKIP] Sin series.")
  } else {
    bloque <- purrr::map_dfr(series, function(s) {
      tibble::tibble(
        estructura   = nombre_est,
        codigo_serie = s$idSerie    %||% NA_character_,
        periodicidad = s$frecuencia %||% NA_character_,
        tipo_cifra   = NA_character_,
        unidad       = s$unidad     %||% NA_character_,
        fecha_inicio = NA_character_,
        fecha_fin    = NA_character_,
        titulo_serie = s$titulo     %||% NA_character_
      )
    })
    resultados[[nombre_est]] <- bloque
    message(sprintf("  %d serie(s) encontrada(s).", nrow(bloque)))
  }

  # Guardar progreso
  procesadas <- c(procesadas, id_est)
  saveRDS(procesadas, ruta_prog)

  # Pausa entre estructuras (cada 10 estructuras pausa más larga)
  if (i %% 10 == 0 && i < n_total) {
    message(sprintf("  [Pausa de %d s después de %d estructuras]",
                    PAUSA_BLOQUE, i))
    Sys.sleep(PAUSA_BLOQUE)
  }
}


# ── Paso 3: Consolidar y guardar CSV ---------------------------------------

message("\n=== Paso 3: Guardando catálogo ===")

catalogo_nuevo <- bind_rows(resultados)

if (nrow(catalogo_nuevo) == 0) {
  stop("No se obtuvieron series. Revisa tu token y la conectividad.")
}

# Si ya existe un catálogo previo, combinar (actualizar fechas, agregar nuevas)
if (file.exists(RUTA_SALIDA)) {
  cat_previo <- read_csv(RUTA_SALIDA, col_types = cols(.default = "c"),
                         show_col_types = FALSE)
  catalogo_combinado <- bind_rows(cat_previo, catalogo_nuevo) %>%
    distinct(codigo_serie, .keep_all = TRUE)
  message("  Series en catálogo previo: ", nrow(cat_previo))
  message("  Series nuevas añadidas:    ", nrow(catalogo_nuevo) - nrow(cat_previo))
} else {
  catalogo_combinado <- catalogo_nuevo
}

write_csv(catalogo_combinado, RUTA_SALIDA)
message("  Catálogo guardado en: ", RUTA_SALIDA)
message("  Total de series: ", nrow(catalogo_combinado))


# ── Paso 4: Reconstruir sysdata.rda ----------------------------------------

message("\n=== Paso 4: Reconstruyendo sysdata.rda ===")
source("data-raw/construir_catalogo.R")

message("\n=== Actualización completada ===")
message("Recuerda hacer load_all() o reinstalar el paquete para usar el catálogo actualizado.")


# ── Operador interno --------------------------------------------------------
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
