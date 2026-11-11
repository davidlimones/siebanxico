# catalog.R ---------------------------------------------------------------
#
# El catálogo interno (`catalogo_series_sie`) es un data frame con metadatos
# de las series del SIE obtenidos por el autor y almacenados en
# `R/sysdata.rda`. Este archivo NO se distribuye en el repositorio público
# para cumplir con los términos del SIE. Ver `data-raw/README.md`.
#
# Columnas del catálogo (generadas por data-raw/construir_catalogo.R):
#   - codigo_serie     : clave de la serie (ej. "SF43718")
#   - titulo_serie     : título original del portal SIE
#   - titulo_completo  : título legible; combina estructura + serie cuando el
#                        título original es ambiguo (ej. "3.1 a 3.5")
#   - titulo_estructura: nombre de la estructura temática del SIE
#   - sector           : alias de titulo_estructura (para búsquedas temáticas)
#   - frecuencia       : periodicidad de publicación (ej. "Diaria", "Mensual")
#   - tipo_cifra       : naturaleza del dato (ej. "Saldos", "Flujos")
#   - unidad           : unidad de medida (ej. "Millones de Pesos")
#   - fecha_inicio     : primera fecha disponible (Date)
#   - fecha_fin        : última fecha disponible  (Date)
# -------------------------------------------------------------------------


# Helpers internos --------------------------------------------------------

#' @noRd
catalogo_disponible <- function() {
  exists("catalogo_series_sie", envir = asNamespace("siebanxico"),
         inherits = FALSE)
}

#' @noRd
check_catalogo <- function() {
  if (!catalogo_disponible()) {
    stop(
      "El catalogo interno no esta disponible.\n",
      "  El archivo 'R/sysdata.rda' no se distribuye en el repositorio ",
      "publico.\n",
      "  Consulta 'data-raw/README.md' para instrucciones sobre como ",
      "construir el catalogo con 'data-raw/construir_catalogo.R'.",
      call. = FALSE
    )
  }
}


#' @noRd
validar_texto <- function(x, nombre) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || nchar(trimws(x)) == 0) {
    stop("'", nombre, "' debe ser una cadena de caracteres no vacia.",
         call. = FALSE)
  }
}

#' @noRd
regex_catalogo <- function(x, ignorar_mayusculas) {
  patron <- sin_acentos(x)
  tryCatch(
    {
      stringi::stri_detect_regex("", patron)
      stringr::regex(patron, ignore_case = ignorar_mayusculas)
    },
    error = function(e) stop("'", x, "' no es una expresion regular valida.",
                             call. = FALSE)
  )
}

#' @noRd
sin_acentos <- function(x) stringi::stri_trans_general(x, "Latin-ASCII")


# Funciones exportadas ----------------------------------------------------

#' Buscar series en el catálogo interno por palabra clave
#'
#' Busca coincidencias en los campos `titulo_serie` y `titulo_estructura`
#' del catálogo interno. **Requiere el catálogo privado.**
#'
#' @param keyword Palabra clave o expresión regular
#'   (ej. `"tipo de cambio"`, `"TIIE"`, `"inflaci[oó]n"`).
#' @param ignorar_mayusculas Lógico. Si es `TRUE` (por defecto), la búsqueda
#'   no distingue mayúsculas ni minúsculas.
#'
#' @return Un tibble con las filas del catálogo que coincidan, con columnas
#'   `codigo_serie`, `titulo_serie`, `titulo_estructura`, `frecuencia`,
#'   `tipo_cifra`, `unidad`, `fecha_inicio` y `fecha_fin`.
#'
#' @examples
#' \dontrun{
#' buscar_en_catalogo("tipo de cambio")
#' buscar_en_catalogo("TIIE")
#' buscar_en_catalogo("inflaci[oó]n")
#' }
#'
#' @export
buscar_en_catalogo <- function(keyword, ignorar_mayusculas = TRUE) {
  check_catalogo()
  validar_texto(keyword, "keyword")

  patron <- regex_catalogo(keyword, ignorar_mayusculas)
  cat    <- catalogo_series_sie

  idx <- stringr::str_detect(sin_acentos(cat$titulo_completo),   patron) |
         stringr::str_detect(sin_acentos(cat$titulo_estructura), patron)

  resultado <- cat[idx, ]

  if (nrow(resultado) == 0) {
    message("No se encontraron series para '", keyword, "' en el catalogo.")
  } else {
    message(nrow(resultado), " serie(s) encontrada(s).")
  }

  resultado
}


#' Buscar series del catálogo por estructura temática
#'
#' Filtra el catálogo interno por los campos `sector` y `titulo_estructura`
#' (ej. "Encuestas", "Balanza de pagos", "Tipos de cambio diarios"). La
#' búsqueda no distingue mayúsculas ni acentos.
#' **Requiere el catálogo privado.**
#'
#' @param sector_keyword Palabra clave de la estructura (puede ser parcial,
#'   no distingue mayúsculas).
#'
#' @return Un tibble con las series de las estructuras que coincidan.
#'
#' @examples
#' \dontrun{
#' buscar_por_sector("tipo de cambio")
#' buscar_por_sector("mercado de dinero")
#' buscar_por_sector("inflacion")
#' }
#'
#' @export
buscar_por_sector <- function(sector_keyword) {
  check_catalogo()
  validar_texto(sector_keyword, "sector_keyword")

  patron <- regex_catalogo(sector_keyword, TRUE)
  cat    <- catalogo_series_sie
  idx    <- stringr::str_detect(sin_acentos(cat$sector), patron) |
            stringr::str_detect(sin_acentos(cat$titulo_estructura), patron)
  resultado <- cat[idx, ]

  if (nrow(resultado) == 0) {
    message("No se encontraron series para '", sector_keyword, "'.")
  } else {
    message(nrow(resultado), " serie(s) en ",
            length(unique(resultado$titulo_estructura)),
            " estructura(s).")
  }

  resultado
}


#' Obtener claves de series a partir de una estructura temática
#'
#' Devuelve todas las claves de series que pertenecen a una estructura del SIE.
#' Usa [buscar_en_catalogo()] para encontrar el nombre exacto de la estructura.
#' **Requiere el catálogo privado.**
#'
#' @param estructura Nombre exacto de la estructura temática.
#'
#' @return Vector de caracteres con las claves de las series.
#'
#' @examples
#' \dontrun{
#' ids   <- estructura_a_series("Tipos de cambio diarios")
#' datos <- get_sie_series_multiple(ids)
#' }
#'
#' @export
estructura_a_series <- function(estructura) {
  check_catalogo()
  validar_texto(estructura, "estructura")
  resultado <- catalogo_series_sie$codigo_serie[
    catalogo_series_sie$titulo_estructura == estructura
  ]
  if (length(resultado) == 0) {
    message("No se encontro la estructura '", estructura, "' en el catalogo.")
    message("Usa buscar_en_catalogo() para encontrar el nombre exacto.")
  }
  resultado
}


#' Ver un resumen del catálogo interno
#'
#' Muestra cuántas series y estructuras temáticas contiene el catálogo interno,
#' y devuelve invisiblemente el data frame completo.
#' **Requiere el catálogo privado.**
#'
#' @return El catálogo completo (invisiblemente).
#'
#' @examples
#' \dontrun{
#' resumen_catalogo()
#' }
#'
#' @export
resumen_catalogo <- function() {
  check_catalogo()
  cat <- catalogo_series_sie
  message("Catalogo SIE:")
  message("  Series      : ", format(nrow(cat), big.mark = ","))
  message("  Estructuras : ", length(unique(cat$titulo_estructura)))
  message("  Periodicidades: ",
          paste(sort(unique(cat$frecuencia)), collapse = ", "))
  invisible(cat)
}
