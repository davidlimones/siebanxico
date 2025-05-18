#' Get metadata for a specific series
#'
#' @param id Series ID.
#' @return A list with metadata details.
#' @export
get_sie_metadata <- function(id) {
  url <- glue::glue("https://www.banxico.org.mx/SieAPIRest/service/v1/series/{id}")
  res <- httr::GET(url, httr::add_headers("Bmx-Token" = get_token()), httr::accept_json())
  if (httr::status_code(res) != 200) stop("Error al obtener metadatos.")
  jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"))$bmx$series[[1]]
}
