#' Configurar el token de la API del SIE
#'
#' Guarda tu token personal de la API del SIE de Banxico en las opciones de la
#' sesión de R. Debes llamar esta función antes de cualquier consulta.
#'
#' @param token Tu token personal como cadena de caracteres.
#'
#' @return Mensaje de confirmación (invisible).
#'
#' @details
#' El token se almacena en `options(siebanxico.token = ...)` y sólo persiste
#' durante la sesión de R activa. Para evitar escribirlo cada vez, puedes
#' añadirlo a tu `.Renviron`:
#'
#' ```
#' BANXICO_TOKEN=aqui_va_tu_token
#' ```
#'
#' y luego configurarlo automáticamente en tu `.Rprofile`:
#'
#' ```r
#' siebanxico::set_sie_token(Sys.getenv("BANXICO_TOKEN"))
#' ```
#'
#' Puedes tramitar un token gratuito en:
#' <https://www.banxico.org.mx/SieAPIRest/service/v1/token>
#'
#' @examples
#' \dontrun{
#' set_sie_token("aqui_va_tu_token")
#' }
#'
#' @export
set_sie_token <- function(token) {
  if (!is.character(token) || nchar(trimws(token)) == 0) {
    stop("El token debe ser una cadena de caracteres no vacia.")
  }
  options(siebanxico.token = token)
  message("\u2705 Token del SIE configurado correctamente.")
  invisible(token)
}


# Función interna para recuperar el token ----------------------------------------

#' @noRd
get_token <- function() {
  token <- getOption("siebanxico.token")
  if (is.null(token) || nchar(trimws(token)) == 0) {
    message("\u26a0\ufe0f  No se encontro un token configurado.")
    message("\ud83d\udcce Tramita uno gratis en:")
    message("\ud83d\udc49 https://www.banxico.org.mx/SieAPIRest/service/v1/token")
    stop("Usa set_sie_token('TU_TOKEN') antes de hacer consultas.",
         call. = FALSE)
  }
  token
}
