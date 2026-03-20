# JSON de ejemplo que imita la respuesta real del SIE
# IMPORTANTE: el SIE devuelve fechas en formato DD/MM/YYYY (no ISO)
json_ok <- '{
  "bmx": {
    "series": [{
      "idSerie": "SF43718",
      "datos": [
        {"fecha": "02/01/2024", "dato": "17.1543"},
        {"fecha": "03/01/2024", "dato": "17.2001"},
        {"fecha": "04/01/2024", "dato": "N/A"}
      ]
    }]
  }
}'

json_vacio <- '{
  "bmx": {
    "series": [{
      "idSerie": "SF43718",
      "datos": []
    }]
  }
}'

test_that("parse_sie_response devuelve tibble con columnas correctas", {
  resultado <- parse_sie_response(json_ok, "SF43718")

  expect_s3_class(resultado, "tbl_df")
  expect_named(resultado, c("fecha", "valor", "serie"))
  expect_equal(nrow(resultado), 3L)
})

test_that("parse_sie_response convierte fechas al tipo Date", {
  resultado <- parse_sie_response(json_ok, "SF43718")
  expect_s3_class(resultado$fecha, "Date")
  expect_equal(resultado$fecha[1], as.Date("2024-01-02"))
})

test_that("parse_sie_response convierte 'N/A' del SIE a NA numérico", {
  resultado <- parse_sie_response(json_ok, "SF43718")
  expect_true(is.na(resultado$valor[3]))
  expect_type(resultado$valor, "double")
})

test_that("parse_sie_response añade la clave de serie correctamente", {
  resultado <- parse_sie_response(json_ok, "SF43718")
  expect_true(all(resultado$serie == "SF43718"))
})

test_that("parse_sie_response devuelve tibble vacío si no hay datos", {
  expect_warning(
    resultado <- parse_sie_response(json_vacio, "SF43718"),
    "no devolvio datos"
  )
  expect_equal(nrow(resultado), 0L)
  expect_named(resultado, c("fecha", "valor", "serie"))
})
