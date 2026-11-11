# Pruebas contra la API real del SIE. Requieren la variable de entorno
# BANXICO_TOKEN; se omiten si no está definida.

USD <- "SF43718"  # Pesos por dólar, FIX
EUR <- "SF46410"  # Pesos por euro

con_token <- function() {
  token <- Sys.getenv("BANXICO_TOKEN")
  skip_if(token == "", "BANXICO_TOKEN no definido")
  skip_on_cran()
  set_sie_token(token)
}

test_that("get_sie_series descarga el tipo de cambio MXN/USD", {
  con_token()
  d <- suppressMessages(get_sie_series(USD, start = "2024-01-01", end = "2024-03-31"))

  expect_named(d, c("fecha", "valor", "serie"))
  expect_s3_class(d$fecha, "Date")
  expect_type(d$valor, "double")
  expect_true(all(d$serie == USD))
  expect_gt(nrow(d), 50)
  expect_true(all(d$fecha >= as.Date("2024-01-01") & d$fecha <= as.Date("2024-03-31")))
  expect_true(all(d$valor[!is.na(d$valor)] > 10 & d$valor[!is.na(d$valor)] < 30))
})

test_that("get_sie_series descarga el tipo de cambio MXN/EUR", {
  con_token()
  d <- suppressMessages(get_sie_series(EUR, start = "2024-01-01", end = "2024-03-31"))

  expect_gt(nrow(d), 50)
  expect_true(all(d$serie == EUR))
  expect_true(all(d$valor[!is.na(d$valor)] > 10 & d$valor[!is.na(d$valor)] < 30))
})

test_that("get_sie_series_multiple descarga USD y EUR en una sola consulta", {
  con_token()
  d <- suppressMessages(
    get_sie_series_multiple(c(USD, EUR), start = "2024-01-01",
                            end = "2024-03-31", pause = 0)
  )

  expect_setequal(unique(d$serie), c(USD, EUR))
  expect_named(d, c("fecha", "valor", "serie"))
  expect_gt(sum(d$serie == USD), 50)
  expect_gt(sum(d$serie == EUR), 50)
})

test_that("get_sie_series coincide con get_sie_series_multiple", {
  con_token()
  uno  <- suppressMessages(get_sie_series(USD, start = "2024-01-01", end = "2024-01-31"))
  lote <- suppressMessages(
    get_sie_series_multiple(USD, start = "2024-01-01", end = "2024-01-31", pause = 0)
  )
  expect_equal(uno, lote)
})

test_that("get_sie_metadata e search_sie_series responden", {
  con_token()
  m <- get_sie_metadata(USD)
  expect_equal(m$id, USD)

  s <- suppressMessages(search_sie_series("tipo de cambio"))
  expect_gt(nrow(s), 0)
  expect_true(all(c("id", "titulo") %in% names(s)))
})
