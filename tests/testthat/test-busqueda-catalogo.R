sin_acentos_test <- function(x) stringi::stri_trans_general(x, "Latin-ASCII")

skip_sin_catalogo <- function() {
  skip_if_not(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico"), inherits = FALSE),
    "Catálogo no disponible"
  )
}

test_that("buscar_en_catalogo no distingue acentos ni mayúsculas", {
  skip_sin_catalogo()
  n <- function(k) nrow(suppressMessages(buscar_en_catalogo(k)))

  expect_gt(n("inflacion"), 0)
  expect_equal(n("inflacion"), n("INFLACIÓN"))
  expect_equal(n("inflacion"), n("inflación"))
})

test_that("buscar_en_catalogo respeta ignorar_mayusculas y acepta regex", {
  skip_sin_catalogo()
  sensible <- suppressMessages(buscar_en_catalogo("TIIE", ignorar_mayusculas = FALSE))
  expect_true(all(grepl("TIIE", paste(sensible$titulo_completo, sensible$titulo_estructura))))

  expect_gt(nrow(suppressMessages(buscar_en_catalogo("tipos? de cambio"))), 0)
})

test_that("buscar_en_catalogo devuelve 0 filas y avisa si no hay coincidencias", {
  skip_sin_catalogo()
  expect_message(r <- buscar_en_catalogo("zzzxxxqqq"), "No se encontraron")
  expect_equal(nrow(r), 0L)
})

test_that("buscar_en_catalogo encuentra las series de tipo de cambio", {
  skip_sin_catalogo()
  # Los títulos usan "Tipos de cambio" (plural): conviene buscar con regex.
  usd <- suppressMessages(buscar_en_catalogo("tipos? de cambio"))
  expect_true("SF43718" %in% usd$codigo_serie)

  eur <- suppressMessages(buscar_en_catalogo("respecto al peso mexicano - Euro"))
  expect_true("SF46410" %in% eur$codigo_serie)
})

test_that("buscar_por_sector filtra por sector y por estructura, sin acentos", {
  skip_sin_catalogo()
  r <- suppressMessages(buscar_por_sector("encuestas"))
  expect_gt(nrow(r), 0)
  expect_true(all(grepl("encuestas", sin_acentos_test(paste(r$sector, r$titulo_estructura)),
                        ignore.case = TRUE)))

  expect_equal(nrow(suppressMessages(buscar_por_sector("INFLACIÓN"))),
               nrow(suppressMessages(buscar_por_sector("inflacion"))))
})

test_that("buscar_por_sector avisa si no hay coincidencias", {
  skip_sin_catalogo()
  expect_message(r <- buscar_por_sector("zzzxxxqqq"), "No se encontraron")
  expect_equal(nrow(r), 0L)
})

test_that("estructura_a_series devuelve las claves de una estructura exacta", {
  skip_sin_catalogo()
  cat <- siebanxico:::catalogo_series_sie
  est <- cat$titulo_estructura[1]

  ids <- estructura_a_series(est)
  expect_type(ids, "character")
  expect_setequal(ids, cat$codigo_serie[cat$titulo_estructura == est])
})

test_that("estructura_a_series avisa con una estructura inexistente", {
  skip_sin_catalogo()
  expect_message(r <- estructura_a_series("No existe"), "No se encontro")
  expect_length(r, 0)
})

test_that("resumen_catalogo informa y devuelve el catálogo invisiblemente", {
  skip_sin_catalogo()
  expect_message(r <- withVisible(resumen_catalogo()), "Series")
  expect_false(r$visible)
  expect_s3_class(r$value, "data.frame")
})

test_that("get_sie_series valida start contra el catálogo antes de llamar a la API", {
  skip_sin_catalogo()
  # SF43718 inicia en 1991-11-12
  expect_error(get_sie_series("SF43718", start = "1980-01-01"), "anterior al inicio")
})

test_that("get_sie_series_multiple valida start contra el catálogo", {
  skip_sin_catalogo()
  expect_error(get_sie_series_multiple(c("SF43718", "SF46410"), start = "1980-01-01"),
               "anterior a la mas temprana")
})

test_that("series fuera del catálogo generan advertencia", {
  skip_sin_catalogo()
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))
  local_mocked_bindings(
    GET = function(...) structure(list(url = "https://example.test", status_code = 500L),
                                  class = "response"),
    .package = "httr"
  )
  expect_warning(
    try(get_sie_series("NOEXISTE1", start = "2024-01-01"), silent = TRUE),
    "no se encontro en el catalogo"
  )
})

test_that("flujo: buscar en el catálogo y descargar las claves encontradas", {
  skip_sin_catalogo()
  set_sie_token("token_falso")
  withr::defer(options(siebanxico.token = NULL))
  pedido <- NULL
  local_mocked_bindings(
    GET = function(u, ...) {
      pedido <<- as.character(u)
      structure(list(url = "https://example.test", status_code = 200L,
                     content = charToRaw('{"bmx":{"series":[]}}'),
                     headers = list(`Content-Type` = "application/json")),
                class = "response")
    },
    .package = "httr"
  )

  hallazgos <- suppressMessages(buscar_en_catalogo("tipos? de cambio"))
  ids <- head(hallazgos$codigo_serie[hallazgos$frecuencia == "Diaria"], 3)
  expect_length(ids, 3)

  suppressMessages(get_sie_series_multiple(ids, start = "2024-01-01",
                                           end = "2024-01-31", pause = 0))
  expect_match(pedido, paste(ids, collapse = ","), fixed = TRUE)
})


# Validación de entradas ---------------------------------------------------

test_that("las búsquedas rechazan entradas que no son texto no vacío", {
  skip_sin_catalogo()
  for (mala in list("", "   ", NA_character_, NULL, 123, c("a", "b"))) {
    expect_error(buscar_en_catalogo(mala), "cadena de caracteres no vacia")
    expect_error(buscar_por_sector(mala), "cadena de caracteres no vacia")
    expect_error(estructura_a_series(mala), "cadena de caracteres no vacia")
  }
})

test_that("las búsquedas rechazan expresiones regulares inválidas", {
  skip_sin_catalogo()
  expect_error(buscar_en_catalogo("["), "expresion regular")
  expect_error(buscar_por_sector("("), "expresion regular")
})

# Forma del resultado ------------------------------------------------------

test_that("buscar_en_catalogo devuelve un tibble con las columnas del catálogo", {
  skip_sin_catalogo()
  r <- suppressMessages(buscar_en_catalogo("TIIE"))
  expect_s3_class(r, "tbl_df")
  expect_identical(names(r), names(siebanxico:::catalogo_series_sie))
  expect_false(anyDuplicated(r$codigo_serie) > 0)
})

test_that("cada resultado coincide con la palabra clave en título o estructura", {
  skip_sin_catalogo()
  r <- suppressMessages(buscar_en_catalogo("inflacion"))
  texto <- sin_acentos_test(paste(r$titulo_completo, r$titulo_estructura))
  expect_true(all(grepl("inflacion", texto, ignore.case = TRUE)))
})

test_that("buscar_en_catalogo encuentra por estructura aunque el título no la mencione", {
  skip_sin_catalogo()
  cat <- siebanxico:::catalogo_series_sie
  # SF43718 se titula "Fecha de determinación (FIX)": solo la estructura dice
  # "Tipos de cambio diarios".
  r <- suppressMessages(buscar_en_catalogo("Tipos de cambio diarios"))
  expect_true("SF43718" %in% r$codigo_serie)
  expect_false(grepl("tipos de cambio", cat$titulo_serie[cat$codigo_serie == "SF43718"],
                     ignore.case = TRUE))
})

test_that("una alternación con | une los resultados de ambos términos", {
  skip_sin_catalogo()
  n <- function(k) nrow(suppressMessages(buscar_en_catalogo(k)))
  a <- suppressMessages(buscar_en_catalogo("TIIE"))
  b <- suppressMessages(buscar_en_catalogo("inflacion"))
  ab <- suppressMessages(buscar_en_catalogo("TIIE|inflacion"))

  expect_setequal(ab$codigo_serie, union(a$codigo_serie, b$codigo_serie))
})

test_that("los códigos devueltos existen en el catálogo y son únicos por serie", {
  skip_sin_catalogo()
  cat <- siebanxico:::catalogo_series_sie
  r <- suppressMessages(buscar_en_catalogo("tipos? de cambio"))
  expect_true(all(r$codigo_serie %in% cat$codigo_serie))
  expect_equal(anyDuplicated(r$codigo_serie), 0L)
})

test_that("buscar_por_sector devuelve series de un sector real con sus columnas", {
  skip_sin_catalogo()
  cat <- siebanxico:::catalogo_series_sie
  sector <- cat$sector[1]
  r <- suppressMessages(buscar_por_sector(sector))
  expect_s3_class(r, "tbl_df")
  expect_true(all(c("codigo_serie", "sector", "titulo_estructura") %in% names(r)))
  expect_true(any(r$sector == sector))
})

test_that("los mensajes informan el número de series encontradas", {
  skip_sin_catalogo()
  expect_message(buscar_en_catalogo("TIIE"), "serie\\(s\\) encontrada\\(s\\)")
  expect_message(buscar_por_sector("encuestas"), "estructura\\(s\\)")
})
