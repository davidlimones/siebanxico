# Pruebas sin red: se sustituye httr::GET por una respuesta simulada.

json_usd_eur <- '{"bmx":{"series":[
  {"idSerie":"SF43718","titulo":"USD","datos":[
    {"fecha":"02/01/2024","dato":"16.9700"},
    {"fecha":"03/01/2024","dato":"N/E"}]},
  {"idSerie":"SF46410","titulo":"EUR","datos":[
    {"fecha":"02/01/2024","dato":"18.7000"}]}]}}'

respuesta_falsa <- function(codigo = 200L, cuerpo = json_usd_eur) {
  structure(list(url = "https://example.test", status_code = codigo,
                 content = charToRaw(cuerpo),
                 headers = list(`Content-Type` = "application/json; charset=UTF-8")),
            class = "response")
}

test_that("get_sie_series_multiple parsea varias series y convierte N/E a NA", {
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))
  local_mocked_bindings(GET = function(...) respuesta_falsa(), .package = "httr")

  d <- suppressMessages(
    get_sie_series_multiple(c("SF43718", "SF46410"), start = "2024-01-01",
                            end = "2024-01-31", pause = 0)
  )
  expect_equal(nrow(d), 3L)
  expect_equal(d$serie, c("SF43718", "SF43718", "SF46410"))
  expect_equal(d$valor[1], 16.97)
  expect_true(is.na(d$valor[2]))
})

test_that("get_sie_series falla con mensaje claro ante HTTP 429 y 404", {
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))

  local_mocked_bindings(GET = function(...) respuesta_falsa(429L, ""), .package = "httr")
  expect_error(suppressWarnings(get_sie_series("SF43718", start = "2024-01-01")), "429")

  local_mocked_bindings(GET = function(...) respuesta_falsa(404L, ""), .package = "httr")
  expect_error(suppressWarnings(get_sie_series("SF43718", start = "2024-01-01")), "404")
})

test_that("get_sie_series_multiple hace pausa solo entre bloques", {
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))
  pausas <- 0L
  local_mocked_bindings(GET = function(...) respuesta_falsa(), .package = "httr")
  local_mocked_bindings(Sys.sleep = function(time) pausas <<- pausas + 1L, .package = "base")

  ids <- paste0("SFX", seq_len(165))
  suppressMessages(suppressWarnings(
    get_sie_series_multiple(ids, start = "2024-01-01", end = "2024-01-31", pause = 1)
  ))
  expect_equal(pausas, 2L)
})

test_that("por defecto, end es hoy y no depende de la fecha de fin del catálogo", {
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))
  url <- NULL
  local_mocked_bindings(
    GET = function(u, ...) { url <<- as.character(u); respuesta_falsa() },
    .package = "httr"
  )

  expect_no_message(get_sie_series("SF43718", start = "2024-01-01"))
  expect_match(url, paste0("/", Sys.Date(), "$"))

  msgs <- testthat::capture_messages(
    get_sie_series_multiple(c("SF43718", "SF46410"), start = "2024-01-01", pause = 0)
  )
  expect_false(any(grepl("posterior|desactualizado", msgs)))
  expect_match(url, paste0("/", Sys.Date(), "$"))
})
