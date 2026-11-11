test_that("get_sie_metadata rechaza id vacío", {
  expect_error(get_sie_metadata(""),  "no vacia")
  expect_error(get_sie_metadata("  "), "no vacia")
})
