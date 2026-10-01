# ==============================================================================================
# inference_solution.R — the reference implementation.
#
# READ THIS ONLY IF YOU ARE STUCK. The point of the lab is that YOU write R/inference.R, because
# that is what makes the resume line defensible. Reading this and copying it produces a file you
# cannot defend under questioning, which is worse than not having the line at all.
#
# If you do read it: close it, and rewrite your own version from memory. Being able to reproduce the
# logic unaided is the actual deliverable. The file is not.
# ==============================================================================================


# Sample size for a two-arm comparison. The derivation is in README.md section 2.
required_sample_size <- function(effect, sd, alpha = 0.05, power = 0.80) {
  # A zero variance would make the requirement infinite, and a zero effect would too. Both are
  # caller errors, so they should be errors rather than an infinite number returned quietly.
  if (sd <= 0) stop("sd must be positive")
  if (effect == 0) stop("effect must be non-zero")

  # qnorm(1 - alpha/2): the two-sided critical value -> 1.96 at alpha = 0.05.
  z_alpha <- qnorm(1 - alpha / 2)
  # qnorm(power): the value that leaves (1 - power) of the distribution above it -> 0.84 at 0.80.
  z_power <- qnorm(power)

  effect_size <- abs(effect) / sd
  # ceiling(), not round(): a fraction of an observation cannot be collected, and rounding down
  # would silently miss the power target the caller asked for.
  ceiling(2 * (z_alpha + z_power)^2 / effect_size^2)
}


# Welch's t-test: no equal-variance assumption.
welch_test <- function(a, b) {
  # var.equal = FALSE is the whole point — it switches t.test from Student's to Welch's.
  result <- t.test(a, b, var.equal = FALSE)
  # unname() strips the label t.test attaches, so the value compares cleanly to a number.
  list(t = unname(result$statistic), p = unname(result$p.value))
}


# Difference-in-differences from four cell means.
did_estimate <- function(treated_in, treated_out, control_in, control_out) {
  # Each group's own before/after change.
  treated_change <- treated_in - treated_out
  control_change <- control_in - control_out
  # The second difference: what is left after subtracting the change common to both groups.
  list(
    treated_change = treated_change,
    control_change = control_change,
    did            = treated_change - control_change
  )
}


# Mix-neutral mean: reweight so the composition is identical every period.
fixed_weight_mean <- function(values, weights) {
  if (length(values) != length(weights)) stop("values and weights must be the same length")
  # Dividing by the sum of the weights normalises them, so callers may pass shares or raw counts.
  sum(values * weights) / sum(weights)
}


# Cluster bootstrap: resample whole SKUs, not individual observations.
cluster_bootstrap_ci <- function(values, groups, arms, n_boot = 2000, seed = 11) {
  # Fix the seed BEFORE any random draw, so the interval is reproducible and therefore testable.
  set.seed(seed)

  skus <- unique(groups)
  estimates <- numeric(n_boot)

  for (i in seq_len(n_boot)) {
    # Draw SKU names with replacement: one SKU may appear twice, another may not appear at all.
    picked <- sample(skus, length(skus), replace = TRUE)
    # Collect every observation belonging to the picked SKUs.
    index <- unlist(lapply(picked, function(s) which(groups == s)))

    v <- values[index]
    a <- arms[index]

    # A resample can lose one arm entirely. Recording NA keeps it out of the percentile instead of
    # inventing a value that would pull the interval toward zero.
    if (!any(a == "in") || !any(a == "out")) {
      estimates[i] <- NA
      next
    }
    estimates[i] <- mean(v[a == "in"]) - mean(v[a == "out"])
  }

  estimates <- estimates[!is.na(estimates)]
  # The percentile method: the 2.5th and 97.5th percentiles of the bootstrap distribution.
  unname(quantile(estimates, c(0.025, 0.975)))
}
