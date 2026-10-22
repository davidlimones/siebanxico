#' Obtener una serie individual del SIE
#'
#' Consulta una serie del SIE de Banxico mediante su API REST. Si el catálogo
#' interno está disponible, valida fechas y sugiere el rango correcto. Si no,
#' funciona igualmente con las fechas que se le pasen.
#'
#' @param id Clave de la serie (ej. `"SF43718"`).
#' @param start Fecha de inicio en formato `"YYYY-MM-DD"`. Si es `NULL` y el
#'   catálogo está disponible, usa la fecha de inicio real de la serie.
#'   Si no hay catálogo, es obligatorio.
#' @param end Fecha de fin en formato `"YYYY-MM-DD"`. Por defecto, la fecha
#'   de hoy: la API devuelve hasta el último dato publicado, sin depender de
#'   la fecha de fin del catálogo interno.
#'
#' @return Un [tibble][tibble::tibble] con tres columnas:
#'   - `fecha`: fecha de observación (`Date`).
#'   - `valor`: valor numérico de la serie (`double`). Los valores `N/A`
#'     reportados por el SIE se convierten a `NA`.
#'   - `serie`: clave de la serie (`character`).
#'
#' @details
#' Requiere que hayas configurado tu token con [set_sie_token()].
#' Puedes tramitar uno gratis en
#' <https://www.banxico.org.mx/SieAPIRest/service/v1/token>.
#'
#' @examples
#' \dontrun{
#' set_sie_token("tu_token")
#'
#' # Con catálogo cargado (detecta fechas automáticamente)
#' get_sie_series("SF43718")
#'
#' # Especificando rango de fechas
#' get_sie_series("SF43718", start = "2020-01-01", end = "2023-12-31")
#' }
#'
#' @seealso [get_sie_series_multiple()] para consultar varias series a la vez.
#' @export
get_sie_series <- function(id, start = NULL, end = Sys.Date()) {

  tiene_catalogo <- catalogo_disponible()

  if (tiene_catalogo) {
    meta <- catalogo_series_sie[catalogo_series_sie$codigo_serie == id, ]

    if (nrow(meta) == 0) {
      warning("La serie '", id, "' no se encontro en el catalogo interno. ",
              "Se intentara la consulta de todos modos.")
    } else {
      start_real <- as.Date(meta$fecha_inicio)

      if (is.null(start)) start <- start_real
      start <- as.Date(start)
      end   <- as.Date(end)

      if (!is.na(start_real) && start < start_real) {
        stop("La fecha de inicio (", start, ") es anterior al inicio ",
             "disponible para la serie '", id, "' (", start_real, ").")
      }
    }
  }

  if (is.null(start)) {
    stop("Debes indicar 'start'. El catalogo no esta disponible para ",
         "inferir la fecha de inicio de la serie.")
  }

  start <- as.Date(start)
  end   <- as.Date(end)

  url <- glue::glue(
    "https://www.banxico.org.mx/SieAPIRest/service/v1/series/{id}/datos/{start}/{end}"
  )

  res <- httr::GET(
    url,
    httr::add_headers("Bmx-Token" = get_token()),
    httr::accept_json()
  )

  codigo <- httr::status_code(res)
  if (codigo == 429L) {
    stop("Limite de solicitudes alcanzado (HTTP 429). ",
         "Espera unos minutos antes de volver a intentarlo.")
  }
  if (codigo != 200L) {
    stop("Error al consultar la serie '", id, "' (HTTP ", codigo, ").")
  }

  json <- httr::content(res, as = "text", encoding = "UTF-8")
  parse_sie_response(json, id)
}


#' Obtener múltiples series del SIE
#'
#' Consulta un conjunto de series del SIE agrupándolas en bloques de hasta 80
#' (límite de la API) e introduce una pausa configurable entre bloques para
#' respetar los límites de la API.
#'
#' @param ids Vector de caracteres con las claves de las series
#'   (ej. `c("SF43718", "SF46410")`).
#' @param start Fecha de inicio en formato `"YYYY-MM-DD"`. Si es `NULL` y el
#'   catálogo está disponible, usa la fecha más temprana entre todas las series.
#' @param end Fecha de fin. Por defecto, la fecha de hoy: la API devuelve hasta
#'   el último dato publicado, sin depender de la fecha de fin del catálogo
#'   interno.
#' @param pause Segundos de pausa entre bloques de consulta. El valor
#'   predeterminado (60 s) es conservador; puedes reducirlo si tu token tiene
#'   límites más amplios. No se aplica pausa después del último bloque.
#'
#' @return Un [tibble][tibble::tibble] con columnas `fecha`, `valor` y `serie`,
#'   apilando los datos de todas las series. Los valores `N/A` del SIE se
#'   convierten a `NA`.
#'
#' @details
#' La API del SIE permite hasta 80 series por petición. Esta función divide
#' automáticamente cualquier vector más largo en bloques y espera `pause`
#' segundos entre cada petición para evitar el error HTTP 429.
#'
#' @examples
#' \dontrun{
#' set_sie_token("tu_token")
#' series <- c("SF43718", "SF46410", "SF60653")
#' datos  <- get_sie_series_multiple(series, start = "2020-01-01", pause = 30)
#' }
#'
#' @seealso [get_sie_series()] para una sola serie.
#' @export
get_sie_series_multiple <- function(ids, start = NULL, end = Sys.Date(),
                                    pause = 60) {

  if (length(ids) == 0) stop("El vector 'ids' esta vacio.")
  if (!is.numeric(pause) || pause < 0) stop("'pause' debe ser un numero >= 0.")

  tiene_catalogo <- catalogo_disponible()

  if (tiene_catalogo) {
    meta <- catalogo_series_sie[catalogo_series_sie$codigo_serie %in% ids, ]

    no_encontradas <- setdiff(ids, meta$codigo_serie)
    if (length(no_encontradas) > 0) {
      warning(length(no_encontradas), " serie(s) no encontradas en el catalogo: ",
              paste(head(no_encontradas, 5), collapse = ", "),
              if (length(no_encontradas) > 5) "..." else "")
    }

    if (nrow(meta) > 0) {
      start_real <- min(as.Date(meta$fecha_inicio), na.rm = TRUE)

      if (is.null(start)) start <- start_real else start <- as.Date(start)
      end <- as.Date(end)

      if (!is.na(start_real) && start < start_real) {
        stop("La fecha de inicio (", start, ") es anterior a la mas temprana ",
             "disponible (", start_real, ").")
      }
    }
  }

  if (is.null(start)) {
    stop("Debes indicar 'start'. El catalogo no esta disponible para ",
         "inferir la fecha de inicio.")
  }

  start <- as.Date(start)
  end   <- as.Date(end)

  bloques   <- split(ids, ceiling(seq_along(ids) / 80L))
  n_bloques <- length(bloques)

  purrr::map_dfr(seq_along(bloques), function(i) {
    bloque  <- bloques[[i]]
    ids_str <- paste(bloque, collapse = ",")

    if (i > 1) {
      message(glue::glue("  Pausa de {pause} s antes del siguiente bloque..."))
      Sys.sleep(pause)
    }
    message(glue::glue("[{i}/{n_bloques}] Consultando {length(bloque)} serie(s)..."))

    url <- glue::glue(
      "https://www.banxico.org.mx/SieAPIRest/service/v1/series/{ids_str}/datos/{start}/{end}"
    )

    res    <- httr::GET(url,
                        httr::add_headers("Bmx-Token" = get_token()),
                        httr::accept_json())
    codigo <- httr::status_code(res)

    if (codigo == 429L) {
      warning("Limite de solicitudes alcanzado en el bloque ", i,
              " (HTTP 429). Intenta aumentar 'pause'.")
      return(tibble::tibble())
    }
    if (codigo != 200L) {
      warning("Error en el bloque ", i, " (HTTP ", codigo, "). ",
              "Se omite este bloque.")
      return(tibble::tibble())
    }

    json   <- httr::content(res, as = "text", encoding = "UTF-8")
    series <- jsonlite::fromJSON(json, simplifyVector = FALSE)$bmx$series

    purrr::map_dfr(series, function(s) {
      datos <- s$datos
      if (is.null(datos) || length(datos) == 0) return(tibble::tibble())
      fechas  <- vapply(datos, `[[`, character(1), "fecha")
      valores <- vapply(datos, `[[`, character(1), "dato")
      tibble::tibble(
        fecha  = as.Date(fechas, format = "%d/%m/%Y"),
        valor  = suppressWarnings(as.numeric(gsub(",", "", valores))),
        serie  = s$idSerie
      )
    })
  })
}


#' Procesar la respuesta JSON de una serie individual
#'
#' Parsea la respuesta cruda de la API del SIE y devuelve un tibble ordenado.
#' Los valores `"N/A"` reportados por el SIE se convierten a `NA` numérico.
#'
#' @param json Cadena JSON devuelta por la API.
#' @param id Clave de la serie (se añade como columna `serie`).
#'
#' @return Un [tibble][tibble::tibble] con columnas `fecha`, `valor` y `serie`.
#'
#' @export
parse_sie_response <- function(json, id) {
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  datos  <- parsed$bmx$series[[1]]$datos

  if (is.null(datos) || length(datos) == 0) {
    warning("La serie '", id, "' no devolvio datos para el rango solicitado.")
    return(tibble::tibble(fecha = as.Date(character()),
                          valor = double(),
                          serie = character()))
  }

  fechas  <- vapply(datos, `[[`, character(1), "fecha")
  valores <- vapply(datos, `[[`, character(1), "dato")

  tibble::tibble(
    fecha  = as.Date(fechas, format = "%d/%m/%Y"),
    valor  = suppressWarnings(as.numeric(gsub(",", "", valores))),
    serie  = id
  )
}
