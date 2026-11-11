# Contrasta fecha_inicio/fecha_fin del catálogo con las fechas reales que
# devuelve la API, para una muestra de series por periodicidad. El inicio debe
# coincidir exactamente; el fin puede ser más reciente en la API (el catálogo
# es una foto).
# Requiere BANXICO_TOKEN y el catálogo interno.

test_that("las fechas del catálogo coinciden con las de la API (muestra por periodicidad)", {
  skip_if(Sys.getenv("BANXICO_TOKEN") == "", "BANXICO_TOKEN no definido")
  skip_on_cran()
  skip_if_not(
    exists("catalogo_series_sie", envir = asNamespace("siebanxico"), inherits = FALSE),
    "Catálogo no disponible"
  )
  set_sie_token(Sys.getenv("BANXICO_TOKEN"))
  cat <- siebanxico:::catalogo_series_sie

  set.seed(1)
  muestra <- do.call(rbind, lapply(split(cat, cat$frecuencia), function(x) {
    x[sample(nrow(x), min(3, nrow(x))), ]
  }))

  discrepancias <- character()
  for (i in seq_len(nrow(muestra))) {
    s <- muestra[i, ]
    d <- tryCatch(
      suppressMessages(suppressWarnings(
        get_sie_series(s$codigo_serie, start = s$fecha_inicio, end = Sys.Date())
      )),
      error = function(e) NULL
    )
    Sys.sleep(1)

    if (is.null(d) || nrow(d) == 0) {
      discrepancias <- c(discrepancias, paste(s$codigo_serie, s$frecuencia, "sin datos"))
      next
    }
    ini_api <- min(d$fecha)
    fin_api <- max(d$fecha)
    if (ini_api != s$fecha_inicio) {
      discrepancias <- c(discrepancias, sprintf(
        "%s (%s): inicio catalogo %s, API %s", s$codigo_serie, s$frecuencia,
        s$fecha_inicio, ini_api))
    }
    # El catálogo es una foto: la API puede tener datos más nuevos, pero no
    # debe tener menos. fecha_fin del catálogo es el cierre del periodo, y la
    # API fecha los periodos no diarios al inicio (o a la 1ª/2ª quincena).
    minimo <- if (s$frecuencia == "Diaria") s$fecha_fin
              else as.Date(format(s$fecha_fin, "%Y-%m-01"))
    if (fin_api < minimo) {
      discrepancias <- c(discrepancias, sprintf(
        "%s (%s): fin catalogo %s, API %s", s$codigo_serie, s$frecuencia,
        s$fecha_fin, fin_api))
    }
  }

  expect_equal(discrepancias, character(0))
})
