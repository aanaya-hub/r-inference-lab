# R inference lab — a guided exercise, not a finished artifact

**What it is:** a small, verifiable R exercise that covers exactly the statistics the campaign's
target roles test — sample size, a two-group test, difference-in-differences, a mix-neutral mean and
a cluster bootstrap.

**Stack:** R (base only — no packages to install)

**Status:** **the scaffold is finished; the five functions are yours to write.**

---

## Read this first, because it is the point of the whole thing

`R/inference.R` contains five functions that raise `stop("not implemented yet")`. That is deliberate.

The resume lists R under **"working knowledge (past-work exposure, not hands-on delivery)"**. The only
honest way to change that line is for you to write the code, run it, and be able to defend every
line in an interview. If this lab arrived finished and you pushed it, you would be claiming a skill
you had not exercised — which is precisely the inflation this campaign forbids.

**So the rule for this repository is:**

> The resume line does not change until `Rscript R/verify.R` passes on **your** code, unaided.

`R/solution/inference_solution.R` exists so you are never stuck. If you read it, close it and rewrite
your own version from memory. The file is not the deliverable. Being able to reproduce the logic
without it is.

## The 20-minute loop

```bash
cd r-inference-lab

Rscript R/verify.R                 # tells you what is wrong, one function at a time
Rscript R/verify.R --solution      # proves the checks themselves are correct (29/29)
Rscript R/benchmark.R              # compares R against the Python analysis
```

Run `verify.R` after every function you implement. It is designed to be run twenty times in a row.

**First run, before you write anything:** `8 passed, 21 failed`. The 8 that pass are data-integrity
checks that do not depend on your code — they confirm you are looking at the same panel the Python
analysis uses, with the same 27 discounted lines and the same known truth of **MXN −1,900.37**.

## What each function must do

### 1. `required_sample_size(effect, sd, alpha = 0.05, power = 0.80)`

```
n per arm = 2 * (z_(1-alpha/2) + z_(1-beta))^2 / (effect / sd)^2
```

`qnorm()` is R's normal quantile function: `qnorm(0.975)` = 1.96, `qnorm(0.80)` = 0.84. Use
`ceiling()`, not `round()` — you cannot collect a fraction of an observation, and rounding down
silently misses the power target.

**Why it matters:** this is the exact calculation a real screening question asked for in September
2026, and the answer was no. It is now a number you can produce on demand.

### 2. `welch_test(a, b)`

`t.test(a, b, var.equal = FALSE)`. Return the statistic and the p-value.

**Why Welch:** Student's t-test assumes both groups share a variance. The treated SKUs here are a
different product family at a different price point, so that assumption is not plausible — and not
assuming it costs nothing.

### 3. `did_estimate(treated_in, treated_out, control_in, control_out)`

```
treated_change = treated_in - treated_out
control_change = control_in - control_out
DiD            = treated_change - control_change
```

**Why the second difference:** it subtracts whatever moved both groups over the same window, so what
remains is the change specific to the treated group.

### 4. `fixed_weight_mean(values, weights)`

`sum(values * weights) / sum(weights)`. Dividing by the sum normalises the weights, so callers can
pass shares or raw counts.

**Why it matters — this is the finding.** The plain monthly mean of a group moves when the *mix* of
products sold changes, even if every product's margin is unchanged. Re-weighting to a constant mix
removes that. In this data the mix-neutral control series has a standard deviation of **exactly 0**,
which proves the control group's movement was 100% composition and that **there was no price or cost
shock for the difference-in-differences to remove**. That is the honest bound on what the design buys.

### 5. `cluster_bootstrap_ci(values, groups, arms, n_boot = 2000, seed = 11)`

For each iteration, resample whole SKU names with replacement, recompute the difference in means,
then take the 2.5th and 97.5th percentiles. `set.seed(seed)` **first**.

**Why cluster:** lines from the same SKU are not independent — they share a price, a cost and a
customer base. Resampling individual lines would produce a narrow, confident interval around a
number supported by four treated SKUs. Resampling whole SKUs is the honest interval, and it is much
wider.

## What "finished" means

| Gate | Command | Pass condition |
| --- | --- | --- |
| Your code is correct | `Rscript R/verify.R` | **29 passed, 0 failed** |
| The checks are correct | `Rscript R/verify.R --solution` | **29 passed, 0 failed** |
| R agrees with Python | `Rscript R/benchmark.R` | **All comparisons agree** |

The third gate is the strongest evidence this lab produces. It is not a claim about knowing R — it is
a demonstration that the same analysis ran in two languages and produced one answer, to within float
tolerance:

| Metric | Python | R |
| --- | --- | --- |
| Known truth (ATT) | −1900.3704 | −1900.3704 |
| Naive own-change | −1847.0484 | −1847.0484 |
| Control change | 23.6602 | 23.6602 |
| DiD estimate | −1870.7086 | −1870.7086 |
| Welch t | −6.8970 | −6.8970 |
| Fixed-weight control sd | 0.0000 | 0.0000 |
| Sample size, 10% margin effect | 695 | 695 |

## Files

```
r-inference-lab/
├── README.md                          this file
├── R/
│   ├── inference.R                    ← YOU WRITE THESE FIVE FUNCTIONS
│   ├── verify.R                       29 assertions; tells you what is wrong
│   ├── benchmark.R                    R vs Python agreement check
│   └── solution/inference_solution.R  the reference — read only if stuck
└── data/                              empty on purpose; the panel is read from the sibling project
```

**Data comes from the sibling `holding-360` project**, read directly from its published ground truth
rather than copied here, so the two cannot drift apart. Keep both projects checked out side by side.

## Limitations

- **This is a lab, not a portfolio project.** It does not get a repository description, a LinkedIn
  Featured slot, or a line in the "Projects" section of the resume. Its purpose is to make one
  *Skills* line defensible, and it should be described exactly that way if it is discussed at all.
- **R is below the campaign's demand line.** The keyword matrix measured R at **8%** of postings,
  against Python at 78% and SQL at 58%. This lab buys honesty, not keyword coverage — the resume
  line was on the document either way, and this makes it true rather than defensible-by-luck.
- **It teaches five functions, not fluency.** A reviewer who asks an open-ended R question will
  find the edges of this quickly. Say so rather than overclaiming.
- **The data is synthetic** (from `holding-360`). Nothing here is client work.
