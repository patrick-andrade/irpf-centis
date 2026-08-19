test_that("os códigos hierárquicos produzem 118 grupos disjuntos", {
  data <- synthetic_distribution()
  expect_equal(nrow(data), 120L)
  expect_equal(nrow(leaf_distribution(data)), 118L)
  expect_equal(which(!data$is_leaf), c(100L, 110L))
  expect_equal(data$share_lower[data$bin_code == 111L], 0.999)
  expect_equal(data$share_upper[data$bin_code == 120L], 1)
})

test_that("agregados 100 e 110 reconciliam com seus filhos", {
  reconciliation <- reconcile_hierarchy(synthetic_distribution())
  expect_true(all(reconciliation$ok))
  expect_equal(reconciliation$rank_sum_100_gap, 0)
  expect_equal(reconciliation$rank_sum_110_gap, 0)
})

test_that("o gate detecta quebra da hierarquia", {
  broken <- synthetic_distribution()
  broken$contributors[broken$bin_code == 100L] <- -1
  checks <- run_quality_checks(broken)
  expect_equal(checks$status[checks$check == "hierarchical_contributors"], "fail")
})

test_that("diferença monetária da fonte é preservada como aviso", {
  broken <- synthetic_distribution()
  broken$rank_sum[broken$bin_code == 100L] <- -1
  checks <- run_quality_checks(broken)
  expect_equal(checks$status[checks$check == "hierarchical_amounts"], "warn")
})
