# ==============================================================================================
# benchmark.R — do R and Python agree?
#
# WHY THIS FILE EXISTS
#   Two independent implementations of the same statistics are a check on both. If the R answers
#   match the Python answers, then the result does not depend on a library's quirks, an argument
#   order, or a version. If they disagree, one of them is wrong and the difference says which.
#
#   This is the strongest evidence the R lab produces, because it is not a claim about knowing R —
#   it is a demonstration that the same analysis ran in two languages and produced one answer.
#
# HOW TO RUN (from the project root)
#   Rscript R/benchmark.R
#
# REQUIRES
#   The sibling `experiment-design-lab` must have been run at least once, so that
#   `../experiment-design-lab/reports/headline_numbers.csv` exists. Run `make analyse` there first.
#
# DEPENDENCIES
#   Base R only. The Python project writes a flat CSV precisely so this file needs no JSON parser.
# ==============================================================================================

# Use whichever implementation is available: your own if it works, otherwise the solution. The
# benchmark is about agreement between languages, not about your progress, so it should run either way.
your_works <- tryCatch({
  source("R/inference.R")
  # A cheap probe: if the first function still raises, fall back.
  required_sample_size(142.86, 949.96)
  TRUE
}, error = function(e) FALSE)

if (your_works) {
  cat("Benchmarking YOUR R implementation against the Python analysis\n\n")
} else {
  cat("Your R/inference.R is not complete yet — benchmarking the reference solution instead.\n")
  cat("(Finish R/inference.R, then re-run this to benchmark your own work.)\n\n")
  source("R/solution/inference_solution.R")
}

# --- Load the panel, exactly as verify.R does ---------------------------------------------------
gt <- file.path("..", "holding-360", "data", "ground_truth")
headlines_path <- file.path("..", "experiment-design-lab", "reports", "headline_numbers.csv")

if (!dir.exists(gt)) stop(sprintf("ground truth not found at '%s'", gt))
if (!file.exists(headlines_path)) {
  stop(paste0(
    "the Python headline numbers are missing: ", headlines_path, "\n",
    "Run `make analyse` in ../experiment-design-lab first — this benchmark compares against it."
  ))
}

lines <- read.csv(file.path(gt, "document_line.csv"), stringsAsFactors = FALSE)
docs  <- read.csv(file.path(gt, "document.csv"), stringsAsFactors = FALSE)
panel <- merge(lines, docs[, c("document_id", "company_code", "doc_type", "period_month")],
               by = "document_id", all.x = TRUE)
panel <- panel[panel$company_code == "BTM" & panel$doc_type == "customer_invoice", ]
panel$month        <- format(as.Date(panel$period_month), "%Y-%m")
panel$month_number <- as.integer(format(as.Date(panel$period_month), "%m"))
panel$unit_margin  <- panel$line_margin_mxn / panel$quantity
# `discounted` must be derived here too — forgetting it made the truth below evaluate to 0/0 = NaN.
panel$discounted   <- !is.na(panel$discount_pct) & panel$discount_pct > 0
panel$treated_sku    <- panel$item_id %in% c("BTM-1111", "BTM-1112", "BTM-2204", "BTM-2205")
panel$treated_period <- panel$month_number %in% c(3L, 9L, 11L)

treated <- panel[panel$treated_sku, ]
t_in  <- treated$unit_margin[treated$treated_period]
t_out <- treated$unit_margin[!treated$treated_period]
control <- panel[!panel$treated_sku, ]
c_in  <- control$unit_margin[control$treated_period]
c_out <- control$unit_margin[!control$treated_period]

# --- Compute the same quantities in R -----------------------------------------------------------
wt   <- welch_test(t_in, t_out)
real <- did_estimate(mean(t_in), mean(t_out), mean(c_in), mean(c_out))

mix_series <- sapply(sort(unique(control$month)), function(m) {
  sub <- control[control$month == m, ]
  means <- tapply(sub$unit_margin, sub$item_id, mean)
  w <- (table(control$item_id) / nrow(control))[names(means)]
  fixed_weight_mean(as.numeric(means), as.numeric(w))
})

# The known truth: each SKU's list price times its markdown, weighted by discounted lines.
markdown_pcts <- c("BTM-1111" = 0.15, "BTM-1112" = 0.15, "BTM-2204" = 0.20, "BTM-2205" = 0.25)
truth_r <- -sum(sapply(names(markdown_pcts), function(sku) {
  max(panel$unit_price_mxn[panel$item_id == sku]) * markdown_pcts[[sku]] *
    sum(panel$item_id == sku & panel$discounted)
})) / sum(panel$discounted)

# --- Compare against the Python values ----------------------------------------------------------
python <- read.csv(headlines_path, stringsAsFactors = FALSE)
py <- setNames(as.numeric(python$value), python$metric)

# The tolerances are deliberately loose. Different languages sum floats in different orders, and a
# bootstrap uses a different random generator. Demanding bit-identical output would produce a
# failing check for a reason that has nothing to do with correctness.
comparisons <- data.frame(
  metric = c(
    "known truth (ATT)",
    "naive own-change",
    "control change",
    "DiD estimate",
    "Welch t statistic",
    "fixed-weight control sd",
    "sample size, 10% margin effect"
  ),
  python = c(
    py[["truth_att"]], py[["naive_own_change"]], py[["control_change"]], py[["did"]],
    py[["welch_t"]], py[["control_fixed_weight_sd"]], py[["n_10pct_margin_effect"]]
  ),
  r = c(
    truth_r, real$treated_change, real$control_change, real$did, wt$t,
    sd(mix_series), required_sample_size(mean(t_out) * 0.10, sd(t_out))
  ),
  tolerance = c(0.05, 0.05, 0.05, 0.05, 0.02, 0.01, 1)
)

comparisons$difference <- comparisons$r - comparisons$python
# NA-safe: a NaN difference (from a failed computation above) must count as DISAGREEMENT, not as
# an unknown that silently passes. `& !is.na(...)` is what enforces that.
comparisons$agree <- !is.na(comparisons$difference) &
  abs(comparisons$difference) <= comparisons$tolerance

# Print with fixed decimals so the table is readable in a terminal.
print(data.frame(
  metric = comparisons$metric,
  python = round(comparisons$python, 4),
  r      = round(comparisons$r, 4),
  diff   = round(comparisons$difference, 4),
  agree  = ifelse(comparisons$agree, "yes", "NO")
), row.names = FALSE)

cat("\n", strrep("-", 70), "\n", sep = "")
if (all(comparisons$agree)) {
  cat("All comparisons agree. The same analysis, in two languages, gives one answer.\n")
} else {
  bad <- comparisons$metric[!comparisons$agree]
  cat("DISAGREEMENT on: ", paste(bad, collapse = ", "), "\n", sep = "")
  cat("Do not report the R numbers until this is resolved — one implementation is wrong.\n")
  quit(status = 1)
}
