# catalog.R ---------------------------------------------------------------
#
# El catálogo interno (`catalogo_series_sie`) es un data frame con metadatos
# de las series del SIE obtenidos por el autor y almacenados en
# `R/sysdata.rda`. Este archivo NO se distribuye en el repositorio público
# para cumplir con los términos del SIE. Ver `data-raw/README.md`.
#
# Columnas esperadas del catálogo:
#   - codigo_serie    : clave de la serie (ej. "SF43718")
#   - titulo_serie    : título descriptivo
#   - titulo_estructura: nombre de la estructura temática
#   - sector          : sector económico
#   - frecuencia      : frecuencia de publicación
#   - unidad          : unidad de medida
#   - fecha_inicio    : primera fecha disponible (character "YYYY-MM-DD")
#   - fecha_fin       : última fecha disponible  (character "YYYY-MM-DD")
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
      "construir el catalogo.",
      call. = FALSE
    )
  }
}


# Funciones exportadas ----------------------------------------------------

#' Buscar series en el catálogo interno por palabra clave
#'
#' Busca coincidencias en los campos `titulo_serie`, `titulo_estructura` y
#' `sector` del catálogo interno. **Requiere el catálogo privado.**
#'
#' @param keyword Palabra clave (puede ser una expresión regular).
#' @param ignorar_mayusculas Lógico. Si es `TRUE` (por defecto), la búsqueda
#'   no distingue mayúsculas.
#'
#' @return Un tibble con las filas del catálogo que coincidan.
#'
#' @examples
#' \dontrun{
#' buscar_en_catalogo("tipo de cambio")
#' buscar_en_catalogo("TIIE")
#' buscar_en_catalogo("inflacion", ignorar_mayusculas = TRUE)
#' }
#'
#' @export
buscar_en_catalogo <- function(keyword, ignorar_mayusculas = TRUE) {
  check_catalogo()

  patron <- stringr::regex(keyword, ignore_case = ignorar_mayusculas)
  cat    <- catalogo_series_sie

  idx <- stringr::str_detect(cat$titulo_serie,     patron) |
         stringr::str_detect(cat$titulo_estructura, patron) |
         stringr::str_detect(cat$sector,            patron)

  resultado <- cat[idx, ]

  if (nrow(resultado) == 0) {
    message("No se encontraron series para '", keyword, "' en el catalogo.")
  }

  resultado
}


#' Buscar series del catálogo por sector
#'
#' Filtra el catálogo interno por el campo `sector`. **Requiere el catálogo
#' privado.**
#'
#' @param sector_keyword Palabra clave del sector (puede ser parcial, no
#'   distingue mayúsculas).
#'
#' @return Un tibble con las series del sector indicado.
#'
#' @examples
#' \dontrun{
#' buscar_por_sector("tipo de cambio")
#' buscar_por_sector("mercado de dinero")
#' }
#'
#' @export
buscar_por_sector <- function(sector_keyword) {
  check_catalogo()

  patron    <- stringr::regex(sector_keyword, ignore_case = TRUE)
  resultado <- dplyr::filter(
    catalogo_series_sie,
    stringr::str_detect(sector, patron)
  )

  if (nrow(resultado) == 0) {
    message("No se encontraron series para el sector '", sector_keyword, "'.")
  }

  resultado
}


#' Obtener claves de series a partir de una estructura temática
#'
#' Devuelve todas las claves de series que pertenecen a una estructura del SIE.
#' **Requiere el catálogo privado.**
#'
#' @param estructura Nombre exacto de la estructura temática (usa
#'   [buscar_en_catalogo()] para encontrar el nombre correcto).
#'
#' @return Vector de caracteres con las claves de las series.
#'
#' @examples
#' \dontrun{
#' estructura_a_series("Tipo de cambio")
#' }
#'
#' @export
estructura_a_series <- function(estructura) {
  check_catalogo()
  catalogo_series_sie$codigo_serie[
    catalogo_series_sie$titulo_estructura == estructura
  ]
}


#' Ver un resumen del catálogo interno
#'
#' Muestra cuántas series y sectores contiene el catálogo, y devuelve
#' invisiblemente el data frame completo. **Requiere el catálogo privado.**
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
  message("  Series    : ", nrow(cat))
  message("  Sectores  : ", length(unique(cat$sector)))
  message("  Estructuras: ", length(unique(cat$titulo_estructura)))
  invisible(cat)
}
