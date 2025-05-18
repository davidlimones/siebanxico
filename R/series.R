#' @title Obtener una serie individual del SIE
#' @description Consulta una serie del SIE, usando la fecha de inicio que aparece en el SIE como inicio de la serie.
#' @param id Clave de la serie.
#' @param start Fecha de inicio (YYYY-MM-DD). Si no se da, usa el inicio de la serie registrado en SIE.
#' @param end Fecha de fin (YYYY-MM-DD). Por defecto hoy.
#' @return Un tibble con fecha, valor y serie.
#' @export
get_sie_series <- function(id, start = NULL, end = Sys.Date()) {
  check_catalogo_loaded()

  meta <- catalogo_series_sie %>% dplyr::filter(codigo_serie == id)
  if (nrow(meta) == 0) stop("La serie ", id, " no existe en el catálogo del SIE.")

  start_real <- as.Date(meta$fecha_inicio)
  end_real <- as.Date(meta$fecha_fin)

  if (is.null(start)) start <- start_real
  if (is.null(end)) end <- end_real

  start <- as.Date(start)
  end <- as.Date(end)

  if (start < start_real) stop("La fecha de inicio es menor a la disponible para la serie ", id)
  if (end > end_real) stop("La fecha de fin es mayor a la disponible para la serie ", id)

  url <- glue::glue("https://www.banxico.org.mx/SieAPIRest/service/v1/series/{id}/datos/{start}/{end}")
  res <- httr::GET(url, httr::add_headers("Bmx-Token" = get_token()), httr::accept_json())

  if (httr::status_code(res) != 200) stop("Error al consultar la serie: ", id)

  json <- httr::content(res, as = "text", encoding = "UTF-8")
  parse_sie_response(json, id)
}

#' @title Obtener múltiples series del SIE
#' @description Consulta un conjunto de series del SIE para los parámetros dados, se sugieren algunos en caso de no ser especificados de acuerdo con la página del SIE.
#' @param ids Vector de claves de series.
#' @param start Fecha de inicio. Si es NULL, usa fecha más temprana de las series.
#' @param end Fecha de fin. Si es NULL, usa fecha más reciente de las series.
#' @param pause Pausa entre bloques (segundos).
#' @return Un tibble con fecha, valor y serie.
#' @export
get_sie_series_multiple <- function(ids, start = NULL, end = Sys.Date(), pause = 60) {
  check_catalogo_loaded()

  if (length(ids) == 0) stop("La lista de series está vacía.")

  meta <- catalogo_series_sie %>% dplyr::filter(codigo_serie %in% ids)
  if (nrow(meta) == 0) stop("Ninguna de las series proporcionadas existe en el catálogo.")

  start_real <- min(as.Date(meta$fecha_inicio))
  end_real <- max(as.Date(meta$fecha_fin))

  if (is.null(start)) start <- start_real else start <- as.Date(start)
  if (is.null(end)) end <- end_real else end <- as.Date(end)

  if (start < start_real) stop("La fecha de inicio es menor a la disponible para las series solicitadas.")
  if (end > end_real) stop("La fecha de fin es mayor a la disponible para las series solicitadas.")

  bloques <- split(ids, ceiling(seq_along(ids) / 80))

  purrr::map_dfr(seq_along(bloques), function(i) {
    bloque <- bloques[[i]]
    ids_str <- paste(bloque, collapse = ",")

    message(glue::glue("Consultando bloque {i}/{length(bloques)} con {length(bloque)} series..."))

    url <- glue::glue("https://www.banxico.org.mx/SieAPIRest/service/v1/series/{ids_str}/datos/{start}/{end}")
    res <- httr::GET(url, httr::add_headers("Bmx-Token" = get_token()), httr::accept_json())

    if (httr::status_code(res) != 200) {
      warning("Error al consultar bloque ", i, ": status ", httr::status_code(res))
      return(tibble::tibble())
    }

    json <- httr::content(res, as = "text", encoding = "UTF-8")
    series <- jsonlite::fromJSON(json)$bmx$series

    if (i < length(bloques)) Sys.sleep(pause)

    purrr::map_dfr(series, function(s) {
      tibble::tibble(
        fecha = as.Date(s$datos$fecha),
        valor = as.numeric(gsub(",", "", s$datos$dato)),
        serie = s$idSerie
      )
    })
  })
}

#' @title Procesar la respuesta de una serie individual
#' @param json JSON crudo.
#' @param id ID de la serie.
#' @return Tibble ordenado.
#' @export
parse_sie_response <- function(json, id) {
  datos <- jsonlite::fromJSON(json)$bmx$series[[1]]$datos
  tibble::tibble(
    fecha = as.Date(datos$fecha),
    valor = as.numeric(gsub(",", "", datos$dato)),
    serie = id
  )
}

#' @noRd
check_catalogo_loaded <- function() {
  if (!exists("catalogo_series_sie", envir = asNamespace("siebanxico"))) {
    stop("El catálogo de series no está disponible. Asegúrese de que el paquete cargó correctamente.")
  }
}
