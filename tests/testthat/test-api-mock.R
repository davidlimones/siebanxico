# search_sie_series y get_sie_metadata con respuestas simuladas (sin red).

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

test_that("search_sie_series devuelve un tibble con las columnas esperadas", {
  con_token_falso()
  json <- '{"bmx":{"series":[
    {"idSerie":"SF43718","titulo":"Tipo de cambio FIX","frecuencia":"Diaria","unidad":"Pesos por Dólar","banco":"Banxico"},
    {"idSerie":"SF46410","titulo":"Euro","frecuencia":"Diaria"}]}}'
  local_mocked_bindings(GET = function(...) resp(json), .package = "httr")

  r <- search_sie_series("tipo de cambio")
  expect_named(r, c("id", "titulo", "frecuencia", "unidad", "banco"))
  expect_equal(r$id, c("SF43718", "SF46410"))
  expect_true(is.na(r$unidad[2]))
})

test_that("search_sie_series devuelve tibble vacío sin coincidencias", {
  con_token_falso()
  local_mocked_bindings(GET = function(...) resp('{"bmx":{"series":[]}}'), .package = "httr")

  expect_message(r <- search_sie_series("zzz"), "No se encontraron")
  expect_equal(nrow(r), 0L)
  expect_named(r, c("id", "titulo", "frecuencia", "unidad", "banco"))
})

test_that("search_sie_series codifica el keyword en la URL", {
  con_token_falso()
  url <- NULL
  local_mocked_bindings(
    GET = function(u, ...) { url <<- as.character(u); resp('{"bmx":{"series":[]}}') },
    .package = "httr"
  )
  suppressMessages(search_sie_series("tipo de cambio"))
  expect_match(url, "keyword=tipo%20de%20cambio", fixed = TRUE)
})

test_that("search_sie_series y get_sie_metadata reportan errores HTTP", {
  con_token_falso()
  local_mocked_bindings(GET = function(...) resp("", 429L), .package = "httr")
  expect_error(search_sie_series("x"), "429")
  expect_error(get_sie_metadata("SF43718"), "429")

  local_mocked_bindings(GET = function(...) resp("", 500L), .package = "httr")
  expect_error(search_sie_series("x"), "500")
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

test_that("las funciones de consulta exigen token", {
  options(siebanxico.token = NULL)
  expect_error(suppressMessages(search_sie_series("x")), "set_sie_token")
  expect_error(suppressMessages(get_sie_metadata("SF43718")), "set_sie_token")
})
