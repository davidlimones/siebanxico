#' Set your Banxico SIE API Token
#'
#' This function stores your token for authenticating requests to Banxico's SIE API.
#'
#' @param token Your personal token as a character string.
#'
#' @return Message confirming token is set.
#'
#' @details You can request a free API token from Banxico at:
#'   \url{https://www.banxico.org.mx/SieAPIRest/service/v1/token}
#'
#' @examples
#' \dontrun{
#' set_sie_token("tu_token")
#' }
#'
#' @export
set_sie_token <- function(token) {
  options(siebanxico.token = token)
  message("✅ Token del SIE guardado.")
}

#' Internal function to retrieve the token
#'
#' @return The token stored in options, or throws an error if not set.
#' @noRd
get_token <- function() {
  token <- getOption("siebanxico.token")
  if (is.null(token)) {
    message("⚠️ No se encontró un token configurado.")
    message("📎 Puedes tramitar uno gratis aquí:")
    message("👉 https://www.banxico.org.mx/SieAPIRest/service/v1/token")
    stop("❌ Usa set_sie_token('TU_TOKEN') antes de hacer consultas.")
  }
  token
}
