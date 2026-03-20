#' Obtener metadatos de una serie del SIE
#'
#' Consulta la API del SIE para obtener información descriptiva sobre una
#' serie: título, frecuencia, unidad, banco fuente y rango de fechas
#' disponible.
#'
#' @param id Clave de la serie (ej. `"SF43718"`).
#'
#' @return Un [tibble][tibble::tibble] de una fila con las columnas:
#'   - `id`: clave de la serie.
#'   - `titulo`: descripción completa.
#'   - `frecuencia`: frecuencia de publicación.
#'   - `unidad`: unidad de medida.
#'   - `banco`: fuente de la serie.
#'   - `fecha_inicio`: primera fecha disponible (`Date`).
#'   - `fecha_fin`: última fecha disponible (`Date`).
#'
#' @details
#' Requiere token configurado con [set_sie_token()].
#'
#' @examples
#' \dontrun{
#' set_sie_token("tu_token")
#' get_sie_metadata("SF43718")
#' }
#'
#' @export
get_sie_metadata <- function(id) {
  if (!is.character(id) || nchar(trimws(id)) == 0) {
    stop("'id' debe ser una cadena de caracteres no vacia.")
  }

  url <- glue::glue(
    "https://www.banxico.org.mx/SieAPIRest/service/v1/series/{id}"
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
    stop("Error al obtener metadatos de '", id, "' (HTTP ", codigo, ").")
  }

  s <- jsonlite::fromJSON(
    httr::content(res, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )$bmx$series[[1]]

  tibble::tibble(
    id           = s$idSerie     %||% id,
    titulo       = s$titulo      %||% NA_character_,
    frecuencia   = s$frecuencia  %||% NA_character_,
    unidad       = s$unidad      %||% NA_character_,
    banco        = s$banco       %||% NA_character_,
    fecha_inicio = tryCatch(as.Date(s$fechaInicio), error = function(e) NA_real_),
    fecha_fin    = tryCatch(as.Date(s$fechaFin),    error = function(e) NA_real_)
  )
}
