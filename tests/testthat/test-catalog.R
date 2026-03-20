test_that("buscar_en_catalogo falla con mensaje claro si no hay catálogo", {
  skip_if(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo disponible — saltando prueba de catálogo ausente"
  )
  expect_error(buscar_en_catalogo("inflacion"), "sysdata.rda")
})

test_that("buscar_por_sector falla con mensaje claro si no hay catálogo", {
  skip_if(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo disponible — saltando prueba de catálogo ausente"
  )
  expect_error(buscar_por_sector("encuestas"), "sysdata.rda")
})

test_that("estructura_a_series falla con mensaje claro si no hay catálogo", {
  skip_if(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo disponible — saltando prueba de catálogo ausente"
  )
  expect_error(estructura_a_series("Tipo de cambio"), "sysdata.rda")
})

test_that("resumen_catalogo falla con mensaje claro si no hay catálogo", {
  skip_if(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo disponible — saltando prueba de catálogo ausente"
  )
  expect_error(resumen_catalogo(), "sysdata.rda")
})

# Pruebas que sólo corren si el catálogo SÍ está disponible
test_that("buscar_en_catalogo devuelve tibble si el catálogo está disponible", {
  skip_if_not(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo no disponible"
  )
  resultado <- buscar_en_catalogo("tipo de cambio")
  expect_s3_class(resultado, "data.frame")
  expect_true("codigo_serie" %in% names(resultado))
})

test_that("buscar_por_sector devuelve tibble si el catálogo está disponible", {
  skip_if_not(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico")),
    "Catálogo no disponible"
  )
  resultado <- buscar_por_sector("encuestas")
  expect_s3_class(resultado, "data.frame")
})
