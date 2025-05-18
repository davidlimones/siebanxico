#' Search for series by keyword
#'
#' @param keyword Keyword to search in the SIE catalog.
#' @return A tibble with matching series.
#' @export
search_sie_series <- function(keyword) {
  kw <- URLencode(keyword)
  url <- glue::glue("https://www.banxico.org.mx/SieAPIRest/service/v1/series?keyword={kw}")
  res <- httr::GET(url, httr::add_headers("Bmx-Token" = get_token()), httr::accept_json())
  if (httr::status_code(res) != 200) stop("Error en búsqueda.")
  series <- jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"))$bmx$series
  if (length(series) == 0) return(tibble::tibble())
  purrr::map_dfr(series, function(s) {
    tibble::tibble(
      id = s$idSerie,
      titulo = s$titulo,
      frecuencia = s$frecuencia,
      unidad = s$unidad,
      banco = s$banco
    )
  })
}
