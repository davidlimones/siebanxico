# get_sie_metadata con respuestas simuladas (sin red).

resp <- function(cuerpo, codigo = 200L) {
  structure(list(url = "https://example.test", status_code = codigo,
                 content = charToRaw(cuerpo),
                 headers = list(`Content-Type` = "application/json; charset=UTF-8")),
            class = "response")
}

con_token_falso <- function(env = parent.frame()) {
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL), envir = env)
}

test_that("get_sie_metadata reporta errores HTTP", {
  con_token_falso()
  local_mocked_bindings(GET = function(...) resp("", 429L), .package = "httr")
  expect_error(get_sie_metadata("SF43718"), "429")

  local_mocked_bindings(GET = function(...) resp("", 500L), .package = "httr")
  expect_error(get_sie_metadata("SF43718"), "500")
})

test_that("get_sie_metadata devuelve una fila con los campos del SIE", {
  con_token_falso()
  json <- '{"bmx":{"series":[{"idSerie":"SF43718","titulo":"FIX","frecuencia":"Diaria",
    "unidad":"Pesos por Dólar","banco":"Banxico","fechaInicio":"1991-11-12","fechaFin":"2024-01-31"}]}}'
  local_mocked_bindings(GET = function(...) resp(json), .package = "httr")

  m <- get_sie_metadata("SF43718")
  expect_equal(nrow(m), 1L)
  expect_equal(m$id, "SF43718")
  expect_equal(m$fecha_inicio, as.Date("1991-11-12"))
  expect_equal(m$fecha_fin, as.Date("2024-01-31"))
})

test_that("get_sie_metadata exige token", {
  options(siebanxico.token = NULL)
  expect_error(suppressMessages(get_sie_metadata("SF43718")), "set_sie_token")
})
