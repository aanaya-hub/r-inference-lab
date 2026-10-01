# ==============================================================================================
# verify.R — the assertion suite. This file tells you whether your implementation is right.
#
# HOW TO RUN (from the project root)
#   Rscript R/verify.R                # check YOUR implementation in R/inference.R
#   Rscript R/verify.R --solution     # check the reference solution
#
# WHY A VERIFIER AND NOT A TEST FRAMEWORK
#   Base R only: no `testthat`, no installation, no version drift. `stopifnot` is enough to assert a
#   number, and the harness below turns each assertion into a readable OK / FAIL line so the first
#   failure is obvious.
#
# THE DATA COMES FROM THE SIBLING PROJECT
#   `holding-360` publishes the synthetic ground truth this lab analyses. Reading it there rather
#   than copying it into this repo means the two projects cannot drift apart.
# ==============================================================================================

# --- Which implementation to check --------------------------------------------------------------
# `--solution` switches to the reference implementation. Anything else checks your own file.
argv <- commandArgs(trailingOnly = TRUE)
use_solution <- "--solution" %in% argv

if (use_solution) {
  source("R/solution/inference_solution.R")
  cat("Checking the REFERENCE SOLUTION\n")
} else {
  source("R/inference.R")
  cat("Checking YOUR implementation in R/inference.R\n")
}

# --- A tiny check harness -----------------------------------------------------------------------
# `call` is evaluated lazily: if it throws, the error is caught and reported against this check
# rather than killing the whole run. That way one unimplemented function does not hide the state of
# the others — which matters most on the first run, when nothing is implemented yet.
passed <- 0
failed <- 0

check <- function(name, expr) {
  message_from_error <- NULL
  ok <- tryCatch(
    isTRUE(expr),
    error = function(e) {
      message_from_error <<- conditionMessage(e)
      FALSE
    }
  )
  if (ok) {
    passed <<- passed + 1
    cat(sprintf("  OK    %s\n", name))
  } else {
    failed <<- failed + 1
    # Print the error inline, once, so the FAIL line names both what failed and why.
    suffix <- if (is.null(message_from_error)) "" else paste0("   [", message_from_error, "]")
    cat(sprintf("  FAIL  %s%s\n", name, suffix))
  }
  invisible(ok)
}

# `safe()` evaluates an expression that PRODUCES A VALUE, returning `default` if it errors. Without
# it, the first unimplemented function halts the script and the later sections never report.
safe <- function(expr, default) {
  tryCatch(expr, error = function(e) default)
}

# `near()` compares two numbers with a tolerance. Exact equality on floats is a trap: 0.1 + 0.2 is
# not 0.3 in any language, and the fix is always a tolerance, never a rounded comparison.
near <- function(a, b, tol = 0.01) {
  is.finite(a) && is.finite(b) && abs(a - b) <= tol
}

# --- Load the panel -----------------------------------------------------------------------------
gt <- file.path("..", "holding-360", "data", "ground_truth")
if (!dir.exists(gt)) {
  stop(sprintf(
    "ground truth not found at '%s'. Run this from the r-inference-lab project root, with the\nsibling holding-360 project checked out alongside it.", gt))
}

lines <- read.csv(file.path(gt, "document_line.csv"), stringsAsFactors = FALSE)
docs  <- read.csv(file.path(gt, "document.csv"), stringsAsFactors = FALSE)

# Attach the header fields each line needs. `merge` is the join; all.x keeps every line.
panel <- merge(
  lines,
  docs[, c("document_id", "company_code", "doc_type", "period_month")],
  by = "document_id", all.x = TRUE
)

# bringToMX is the only company that applies markdowns, and only customer invoices are sales.
panel <- panel[panel$company_code == "BTM" & panel$doc_type == "customer_invoice", ]

# Derived columns. `as.Date` parses "2025-01-01"; the month number drives the markdown rule.
panel$month        <- format(as.Date(panel$period_month), "%Y-%m")
panel$month_number <- as.integer(format(as.Date(panel$period_month), "%m"))
panel$unit_margin  <- panel$line_margin_mxn / panel$quantity
panel$unit_price   <- panel$unit_price_mxn
panel$discounted   <- !is.na(panel$discount_pct) & panel$discount_pct > 0

# The treatment definition, mirrored from holding-360's config.py. If the generator ever changes,
# the count assertions below fail loudly rather than the analysis quietly measuring the wrong thing.
treated_skus   <- c("BTM-1111", "BTM-1112", "BTM-2204", "BTM-2205")
markdown_months <- c(3L, 9L, 11L)

panel$treated_sku    <- panel$item_id %in% treated_skus
panel$treated_period <- panel$month_number %in% markdown_months

cat(sprintf("panel: %d lines, %d months, %d treated SKUs\n\n",
            nrow(panel), length(unique(panel$month)),
            length(unique(panel$item_id[panel$treated_sku]))))

# --- 1. The panel is the same panel the Python analysis uses ------------------------------------
# These are integrity checks on the DATA, not on your code. If one fails, nothing else is meaningful.
cat("1. Data integrity (independent of your code)\n")
check("3,911 invoice lines", nrow(panel) == 3911)
check("18 months", length(unique(panel$month)) == 18)
check("27 discounted lines", sum(panel$discounted) == 27)
check("no discounted line outside a treated cell",
      all(panel$treated_sku[panel$discounted]) && all(panel$treated_period[panel$discounted]))

treated <- panel[panel$treated_sku, ]
t_in  <- treated$unit_margin[treated$treated_period]
t_out <- treated$unit_margin[!treated$treated_period]
control <- panel[!panel$treated_sku, ]
c_in  <- control$unit_margin[control$treated_period]
c_out <- control$unit_margin[!control$treated_period]

check("27 treated lines in the treated cell", length(t_in) == 27)
check("98 treated lines outside it", length(t_out) == 98)

# The known true effect: each SKU's list price times its markdown, weighted by discounted lines.
pcts <- c("BTM-1111" = 0.15, "BTM-1112" = 0.15, "BTM-2204" = 0.20, "BTM-2205" = 0.25)
truth <- -sum(sapply(names(pcts), function(s) {
  max(panel$unit_price[panel$item_id == s]) * pcts[[s]] * sum(panel$item_id == s & panel$discounted)
})) / sum(panel$discounted)
cat(sprintf("\nknown true effect (ATT): %.2f MXN per unit\n\n", truth))

# --- 2. required_sample_size --------------------------------------------------------------------
cat("\n2. required_sample_size\n")
base_mean <- mean(t_out)
base_sd   <- sd(t_out)
check("sd of treated unit margin is 949.96", near(base_sd, 949.96, 0.05))
check("10% effect (142.86 MXN) needs 695 lines", near(required_sample_size(142.86, base_sd), 695, 1))
check("5% effect (71.43 MXN) needs 2777 lines", near(required_sample_size(71.43, base_sd), 2777, 1))
check("15% effect (214.30 MXN) needs 309 lines", near(required_sample_size(214.30, base_sd), 309, 1))
check("halving the effect quadruples the sample",
      near(required_sample_size(100, 1000) / required_sample_size(200, 1000), 4, 0.02))
check("returns a whole number of observations",
      isTRUE(all.equal(required_sample_size(143, 950), round(required_sample_size(143, 950)))))

# --- 3. welch_test -----------------------------------------------------------------------------
cat("\n3. welch_test\n")
wt <- safe(welch_test(t_in, t_out), list(t = NA_real_, p = NA_real_))
check("t statistic is -6.90", near(wt$t, -6.90, 0.02))
check("p value is 6.0e-08", near(wt$p, 6.02e-08, 1e-9))
check("identical vectors give p = 1", near(welch_test(c(1, 2, 3), c(1, 2, 3))$p, 1, 1e-9))

# --- 4. did_estimate ----------------------------------------------------------------------------
cat("\n4. did_estimate\n")
check("hand example: did_estimate(6, 10, 9, 10)$did == -3",
      near(did_estimate(6, 10, 9, 10)$did, -3, 1e-9))
check("hand example: treated_change == -4",
      near(did_estimate(6, 10, 9, 10)$treated_change, -4, 1e-9))
check("hand example: control_change == -1",
      near(did_estimate(6, 10, 9, 10)$control_change, -1, 1e-9))

real <- safe(
  did_estimate(mean(t_in), mean(t_out), mean(c_in), mean(c_out)),
  list(treated_change = NA_real_, control_change = NA_real_, did = NA_real_)
)
cat(sprintf("       real cells -> treated %.2f  control %.2f  DiD %.2f\n",
            real$treated_change, real$control_change, real$did))
check("naive own-change is -1847.05", near(real$treated_change, -1847.05, 0.05))
check("DiD is -1870.71", near(real$did, -1870.71, 0.05))
check("DiD is closer to the truth than the naive estimate",
      abs(real$did - truth) <= abs(real$treated_change - truth))

# --- 5. fixed_weight_mean -----------------------------------------------------------------------
cat("\n5. fixed_weight_mean\n")
check("hand example: fixed_weight_mean(c(10, 20), c(.25, .75)) == 17.5",
      near(fixed_weight_mean(c(10, 20), c(0.25, 0.75)), 17.5, 1e-9))
check("weights that do not sum to 1 are normalised",
      near(fixed_weight_mean(c(10, 20), c(1, 3)), 17.5, 1e-9))

# THE FINDING: a mix-neutral control series is EXACTLY flat, because price and landed cost are
# constant per SKU. If this check ever fails, a real shock has entered the data.
ctrl <- control
sku_share <- table(ctrl$item_id) / nrow(ctrl)
monthly_fixed <- safe(sapply(sort(unique(ctrl$month)), function(m) {
  sub <- ctrl[ctrl$month == m, ]
  means <- tapply(sub$unit_margin, sub$item_id, mean)
  w <- sku_share[names(means)]
  fixed_weight_mean(as.numeric(means), as.numeric(w))
}), rep(NA_real_, length(unique(ctrl$month))))
cat(sprintf("       fixed-weight control series: sd = %.4f across %d months\n",
            sd(monthly_fixed), length(monthly_fixed)))
check("the mix-neutral control series does not move (sd < 0.01)", sd(monthly_fixed) < 0.01)
raw_monthly <- sapply(sort(unique(ctrl$month)), function(m) mean(ctrl$unit_margin[ctrl$month == m]))
check("the raw control series DOES move (sd > 50)", sd(raw_monthly) > 50)

# --- 6. cluster_bootstrap_ci --------------------------------------------------------------------
cat("\n6. cluster_bootstrap_ci\n")
# Resample the treated group only, which is where the four-cluster problem bites.
ci <- safe(cluster_bootstrap_ci(
  values = treated$unit_margin,
  groups = treated$item_id,
  arms   = ifelse(treated$treated_period, "in", "out"),
  n_boot = 2000, seed = 11
), c(NA_real_, NA_real_))
cat(sprintf("       bootstrap 95%% CI for the treated change: [%.2f, %.2f]\n", ci[1], ci[2]))
check("returns two ordered bounds", length(ci) == 2 && ci[1] < ci[2])
check("the interval contains the naive own-change", ci[1] <= real$treated_change &&
        real$treated_change <= ci[2])
# A line-level interval would be far narrower than this. The width is the point: four SKUs is not
# much information, and the interval must say so.
check("the interval is wide enough to reflect 4 SKUs (width > 400 MXN)", (ci[2] - ci[1]) > 400)
check("reproducible: same seed gives the same answer",
      isTRUE(all.equal(ci, cluster_bootstrap_ci(treated$unit_margin, treated$item_id,
                                                ifelse(treated$treated_period, "in", "out"),
                                                n_boot = 2000, seed = 11))))

# --- Verdict ------------------------------------------------------------------------------------
cat(sprintf("\n%s\n", strrep("-", 70)))
cat(sprintf("%d passed, %d failed\n", passed, failed))
if (failed > 0) {
  cat("\nNot finished. The failures above name what to fix. See README.md for each section.\n")
  quit(status = 1)
}
cat("\nAll checks pass. Now run: Rscript R/benchmark.R\n")
cat("That compares these answers against the Python analysis; they must agree.\n")
