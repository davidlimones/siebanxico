# test-catalog-datos.R -----------------------------------------------------
#
# Pruebas de calidad de datos sobre el catálogo interno (catalogo_series_sie).
# Complementan a test-catalog.R (que solo valida el comportamiento de las
# funciones cuando el catálogo está/no está disponible) verificando que el
# CONTENIDO del catálogo -- generado por data-raw/construir_catalogo.R a
# partir de catalogo_series_sie_final.parquet -- sea correcto. Todas se
# saltan si el catálogo privado no está disponible (R/sysdata.rda no se
# distribuye, ver data-raw/README.md).

cat_disponible <- function() {
  exists("catalogo_series_sie", envir = asNamespace("siebanxico"), inherits = FALSE)
}

test_that("el catálogo tiene las columnas esperadas", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  columnas_esperadas <- c(
    "codigo_serie", "titulo_serie", "titulo_completo", "titulo_estructura",
    "sector", "frecuencia", "tipo_cifra", "unidad", "fecha_inicio", "fecha_fin"
  )
  expect_true(all(columnas_esperadas %in% names(cat)))
})

test_that("fecha_inicio y fecha_fin son de tipo Date", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  expect_s3_class(cat$fecha_inicio, "Date")
  expect_s3_class(cat$fecha_fin, "Date")
})

test_that("ninguna serie del catálogo tiene fecha_inicio o fecha_fin vacía", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  # construir_catalogo.R / nose.py descartan las series sin datos publicados
  # (ver NEWS.md) -- si aparece un NA aquí, alguna quedó sin filtrar.
  expect_equal(sum(is.na(cat$fecha_inicio)), 0L)
  expect_equal(sum(is.na(cat$fecha_fin)), 0L)
})

test_that("fecha_inicio nunca es posterior a fecha_fin", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  expect_true(all(cat$fecha_inicio <= cat$fecha_fin))
})

test_that("no hay codigo_serie duplicado en el catálogo", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  # El paquete indexa por codigo_serie (get_sie_series(), get_sie_series_multiple())
  # y asume una sola fila por clave -- un duplicado rompería esa suposición.
  expect_equal(anyDuplicated(cat$codigo_serie), 0L)
})

test_that("sector no es simplemente un alias de titulo_estructura", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  # Regresión: antes de leer el parquet, 'sector' se calculaba como
  # sector <- titulo_estructura (el catálogo viejo no traía sector real).
  # Con el parquet, sector es el sector real de Banxico y debe haber
  # muchas menos categorías de sector que de estructuras.
  expect_lt(length(unique(cat$sector)), length(unique(cat$titulo_estructura)))
})

test_that("titulo_completo no tiene NA y combina estructura cuando el título es ambiguo", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  expect_equal(sum(is.na(cat$titulo_completo)), 0L)

  ambiguos <- cat[nchar(cat$titulo_serie) <= 20 | grepl("^[0-9]", cat$titulo_serie), ]
  if (nrow(ambiguos) > 0) {
    expect_true(all(grepl(" - ", ambiguos$titulo_completo[1:min(20, nrow(ambiguos))], fixed = TRUE)))
  }
})

test_that("el catálogo tiene un número razonable de series y frecuencias conocidas", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  # No fijamos un número exacto porque el catálogo crece con cada corrida del
  # scraper -- solo descartamos un fallo catastrófico de lectura/parseo.
  expect_gt(nrow(cat), 50000)

  frecuencias_conocidas <- c("Diaria", "Quincenal", "Mensual", "Bimestral",
                             "Trimestral", "Semestral", "Anual")
  expect_true(all(unique(cat$frecuencia) %in% frecuencias_conocidas))
})

test_that("las fechas del catálogo son coherentes con la periodicidad", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie
  dia <- function(x) format(x, "%d")
  mes <- function(x) as.integer(format(x, "%m"))
  fin_de_mes <- function(x) dia(x + 1) == "01"

  no_diaria <- cat[cat$frecuencia != "Diaria" & cat$frecuencia != "Quincenal", ]
  expect_true(all(dia(no_diaria$fecha_inicio) == "01"))
  expect_true(all(fin_de_mes(no_diaria$fecha_fin)))

  tri <- cat[cat$frecuencia == "Trimestral", ]
  expect_true(all(mes(tri$fecha_inicio) %in% c(1, 4, 7, 10)))

  anual <- cat[cat$frecuencia == "Anual", ]
  expect_true(all(mes(anual$fecha_inicio) == 1))
})

test_that("ninguna fecha_inicio del catálogo es futura ni absurda", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  expect_true(all(cat$fecha_inicio <= Sys.Date()))
  expect_true(all(cat$fecha_inicio >= as.Date("1900-01-01")))
})

test_that("fecha_fin no excede el cierre del año en curso", {
  skip_if_not(cat_disponible(), "Catálogo no disponible")
  cat <- siebanxico:::catalogo_series_sie

  # Las series anuales traen el 31-dic del periodo; nada debería ir más allá.
  limite <- as.Date(paste0(format(Sys.Date(), "%Y"), "-12-31"))
  expect_true(all(cat$fecha_fin <= limite))
})
