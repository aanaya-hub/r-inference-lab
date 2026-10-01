# ==============================================================================================
# inference.R — the functions YOU write.
#
# WHY THIS FILE IS MOSTLY EMPTY, ON PURPOSE
# ------------------------------------------
# The resume lists R under "working knowledge (past-work exposure, not hands-on delivery)". The
# honest way to change that line is for you to write the code and be able to defend every line.
# If this file arrived finished, pushing it would be claiming a skill you had not exercised — which
# is exactly the inflation this campaign forbids.
#
# So: the scaffold, the data loading and the assertion suite in `verify.R` are done. The five
# functions below are yours. `verify.R` will tell you when each one is right.
#
# HOW TO WORK
# -----------
#   1. Read README.md (5 minutes) — it says what each function must do and why.
#   2. Implement one function at a time.
#   3. Run:  Rscript R/verify.R      from the project root.
#      Each assertion that passes prints OK; the first failure tells you what is wrong.
#   4. When everything passes, run:  Rscript R/benchmark.R
#      That compares your R answers against the Python analysis. They must agree.
#   5. Only then does the resume line change.
#
# If you get stuck, `R/solution/inference_solution.R` has a complete implementation. Read it, close
# it, and rewrite yours from memory — the point is the skill, not the file.
#
# STYLE: base R only. No packages. That is deliberate: it means this runs anywhere R runs, and it
# forces the statistics to be visible rather than hidden behind a library call.
# ==============================================================================================


#' Sample size for a two-arm comparison of means.
#'
#' THE FORMULA
#'   n per arm = 2 * (z_(1 - alpha/2) + z_(1 - beta))^2 / (effect / sd)^2
#'
#' `qnorm()` is R's normal quantile function: qnorm(0.975) = 1.96, qnorm(0.80) = 0.84.
#' `ceiling()` rounds up — you cannot run a fraction of an observation, and rounding down would
#' quietly miss the power target.
#'
#' @param effect  the smallest change worth detecting (in the outcome's units). Non-zero.
#' @param sd      standard deviation of the outcome. Must be positive.
#' @param alpha   two-sided false-positive rate. Default 0.05.
#' @param power   target probability of detecting a real effect. Default 0.80.
#' @return integer, the number of observations required in EACH arm.
#' @examples
#'   required_sample_size(142.86, 949.96)   # -> 695
required_sample_size <- function(effect, sd, alpha = 0.05, power = 0.80) {
  stop("not implemented yet — see README.md section 2")
}


#' Welch's t-test comparing two numeric vectors.
#'
#' WHY WELCH AND NOT STUDENT
#'   Student's t-test assumes both groups share a variance. Nothing in this data makes that
#'   plausible — the treated SKUs are a different product family at a different price point. Welch
#'   does not make that assumption, and it costs nothing to use.
#'
#' @param a,b numeric vectors.
#' @return a list with elements `t` (the statistic) and `p` (the two-sided p-value).
#' @examples
#'   welch_test(c(1, 2, 3), c(4, 5, 6))$p   # -> a small number
welch_test <- function(a, b) {
  stop("not implemented yet — see README.md section 3")
}


#' Difference-in-differences from four cell means.
#'
#' THE ARITHMETIC, WRITTEN OUT
#'   treated_change = treated_in  - treated_out
#'   control_change = control_in  - control_out
#'   DiD            = treated_change - control_change
#'
#' The second difference is the whole idea: it subtracts whatever moved both groups over the same
#' window, so the answer is the change that is specific to the treated group.
#'
#' @param treated_in,treated_out,control_in,control_out numeric cell means.
#' @return a named list with `treated_change`, `control_change` and `did`.
#' @examples
#'   did_estimate(6, 10, 9, 10)$did   # -> -3
did_estimate <- function(treated_in, treated_out, control_in, control_out) {
  stop("not implemented yet — see README.md section 4")
}


#' Mix-neutral (fixed-weight) mean of a numeric vector, weighted by `weights`.
#'
#' WHAT IT IS FOR
#'   The plain monthly mean of a group moves when the MIX of products sold changes, even if every
#'   individual product's margin is unchanged. Re-weighting so the product mix is identical every
#'   month removes that effect. What is left is the part of the movement that is NOT composition.
#'
#'   In this data the answer is exactly flat. That is the finding: there is no price or cost shock
#'   for the difference-in-differences to remove.
#'
#' @param values  numeric vector of per-unit margins for one month.
#' @param weights numeric vector of fixed weights, the same length as `values`, in [0, 1].
#' @return numeric scalar: the weighted mean, normalised so the weights sum to 1.
#' @examples
#'   fixed_weight_mean(c(10, 20), c(0.25, 0.75))   # -> 17.5
fixed_weight_mean <- function(values, weights) {
  stop("not implemented yet — see README.md section 5")
}


#' Cluster bootstrap confidence interval for a two-group difference.
#'
#' WHY CLUSTER AND NOT LINE-LEVEL
#'   Lines belonging to the same SKU are not independent: they share a price, a cost and a customer
#'   base. Resampling individual lines would produce a confidently narrow interval around a number
#'   supported by only four treated SKUs. Resampling whole SKUs keeps that dependence intact.
#'
#' HOW TO DO IT
#'   For each of `n_boot` iterations:
#'     1. Draw whole SKU names with replacement — `sample(unique(names), replace = TRUE)`.
#'     2. Recompute the estimate on the resampled set.
#'   Then take the 2.5th and 97.5th percentiles of the estimates.
#'
#'   `set.seed(seed)` first, so the answer is reproducible. A confidence interval that changes
#'   between runs cannot be tested.
#'
#' @param values   numeric vector of per-unit margins.
#' @param groups   character/factor vector: which SKU each value belongs to.
#' @param arms     character/factor vector: which arm each value belongs to ("treated"/"control").
#' @param n_boot   number of bootstrap iterations. Default 2000.
#' @param seed     random seed. Default 11.
#' @return numeric vector of length 2: c(lower, upper) at 95%.
cluster_bootstrap_ci <- function(values, groups, arms, n_boot = 2000, seed = 11) {
  stop("not implemented yet — see README.md section 6")
}
