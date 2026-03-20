#' Buscar series en el SIE por palabra clave
#'
#' Realiza una búsqueda en la API del SIE usando una palabra clave y devuelve
#' las series que coincidan con el término.
#'
#' @param keyword Palabra clave para buscar (ej. `"tipo de cambio"`,
#'   `"inflacion"`, `"TIIE"`).
#'
#' @return Un [tibble][tibble::tibble] con una fila por serie encontrada y las
#'   columnas:
#'   - `id`: clave de la serie.
#'   - `titulo`: descripción de la serie.
#'   - `frecuencia`: frecuencia de publicación.
#'   - `unidad`: unidad de medida.
#'   - `banco`: fuente de la serie.
#'
#'   Devuelve un tibble vacío si no se encontraron coincidencias.
#'
#' @details
#' Esta función consulta directamente la API y no requiere el catálogo interno.
#' Para búsquedas locales más rápidas sobre el catálogo completo, usa
#' [buscar_por_sector()] o [buscar_en_catalogo()].
#'
#' @examples
#' \dontrun{
#' set_sie_token("tu_token")
#' search_sie_series("tipo de cambio")
#' search_sie_series("TIIE 28")
#' }
#'
#' @export
search_sie_series <- function(keyword) {
  if (!is.character(keyword) || nchar(trimws(keyword)) == 0) {
    stop("'keyword' debe ser una cadena de caracteres no vacia.")
  }

  kw  <- URLencode(keyword, reserved = TRUE)
  url <- glue::glue(
    "https://www.banxico.org.mx/SieAPIRest/service/v1/series?keyword={kw}"
  )

  res    <- httr::GET(url,
                      httr::add_headers("Bmx-Token" = get_token()),
                      httr::accept_json())
  codigo <- httr::status_code(res)

  if (codigo == 429L) {
    stop("Limite de solicitudes alcanzado (HTTP 429). ",
         "Espera unos minutos antes de volver a intentarlo.")
  }
  if (codigo != 200L) {
    stop("Error en la busqueda de series (HTTP ", codigo, ").")
  }

  contenido <- jsonlite::fromJSON(
    httr::content(res, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )
  series <- contenido$bmx$series

  if (is.null(series) || length(series) == 0) {
    message("No se encontraron series para '", keyword, "'.")
    return(tibble::tibble(
      id         = character(),
      titulo     = character(),
      frecuencia = character(),
      unidad     = character(),
      banco      = character()
    ))
  }

  purrr::map_dfr(series, function(s) {
    tibble::tibble(
      id         = s$idSerie   %||% NA_character_,
      titulo     = s$titulo    %||% NA_character_,
      frecuencia = s$frecuencia %||% NA_character_,
      unidad     = s$unidad    %||% NA_character_,
      banco      = s$banco     %||% NA_character_
    )
  })
}
