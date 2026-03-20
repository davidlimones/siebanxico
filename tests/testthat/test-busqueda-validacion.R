test_that("search_sie_series rechaza keyword vacío", {
  expect_error(search_sie_series(""),  "no vacia")
  expect_error(search_sie_series("  "), "no vacia")
})

test_that("get_sie_metadata rechaza id vacío", {
  expect_error(get_sie_metadata(""),  "no vacia")
  expect_error(get_sie_metadata("  "), "no vacia")
})
