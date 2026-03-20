test_that("set_sie_token rechaza tokens vacíos", {
  expect_error(set_sie_token(""),  "no vacia")
  expect_error(set_sie_token("  "), "no vacia")
  expect_error(set_sie_token(123),  "cadena de caracteres")
})

test_that("set_sie_token guarda el token correctamente", {
  set_sie_token("token_de_prueba_123")
  expect_equal(getOption("siebanxico.token"), "token_de_prueba_123")

  # Limpieza
  options(siebanxico.token = NULL)
})

test_that("get_token falla con mensaje claro cuando no hay token", {
  options(siebanxico.token = NULL)
  expect_error(siebanxico:::get_token(), "set_sie_token")
})
