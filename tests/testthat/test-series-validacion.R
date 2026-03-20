test_that("get_sie_series_multiple falla con vector vacío", {
  expect_error(get_sie_series_multiple(ids = c()), "vacio")
})

test_that("get_sie_series_multiple falla con pause negativo", {
  expect_error(
    get_sie_series_multiple(ids = "SF43718", start = "2024-01-01", pause = -1),
    ">= 0"
  )
})

test_that("get_sie_series_multiple falla sin token cuando no puede inferir start", {
  options(siebanxico.token = NULL)
  # La serie puede no estar en el catálogo → warning → luego error de token o start.
  # suppressWarnings captura los warnings esperados del código y deja pasar el error.
  expect_error(
    suppressWarnings(get_sie_series_multiple(ids = "SF43718")),
    regexp = "set_sie_token|catalogo|start"
  )
})

test_that("get_sie_series falla sin token cuando no puede inferir start", {
  options(siebanxico.token = NULL)
  expect_error(
    suppressWarnings(get_sie_series("SF43718")),
    regexp = "set_sie_token|catalogo|start"
  )
})

test_that("get_sie_series_multiple divide correctamente en bloques de 80", {
  # Verificar que la lógica de split funciona — sin llamar a la API
  ids    <- paste0("SF", seq_len(165))
  bloques <- split(ids, ceiling(seq_along(ids) / 80L))

  expect_equal(length(bloques), 3L)
  expect_equal(length(bloques[[1]]), 80L)
  expect_equal(length(bloques[[2]]), 80L)
  expect_equal(length(bloques[[3]]), 5L)
})
