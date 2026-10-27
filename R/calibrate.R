# Calibrate the model to StatLine and a cohort rebound target ----
# Step 1: for given parameters, the threshold path F_t is solved so that the simulated
#   BEV stock share matches StatLine exactly in every year.
# Step 2: the mean km elasticity eps_mean is set so that the mean rebound of the target
#   cohort equals the target (PLACEHOLDER 10% for the 2020 cohort, fictitious).
# Step 3: the dispersion of km (km_sdlog) is set so that the mean km of BEVs in use relative
#   to all cars in use matches StatLine in the target year (strength of selection on km).
# Run from the repository root: Rscript R/calibrate.R

library(data.table)
library(ggcpb)

source("R/params.R")
source("R/model.R")

# Data ----
statline <- fread("data/statline_bev_share.csv")
shares <- statline[, .(year, share = bev_share)]
stopifnot(all(c(params$base_year, params$years) %in% shares$year))
params$km_ratio_target$value <- statline[year == params$km_ratio_target$year, km_ratio]

# Calibration of eps_mean ----
calibrate_eps <- function(p, pop, shares, timing = "selection", interval = c(0.005, 0.8)) {
  target <- p$rebound_target
  f <- function(eps_mean) {
    p$eps_mean <- eps_mean
    sim <- simulate_adoption(build_types(pop, p), shares, p, timing)
    cohort_rebound(sim, target$cohort, target$measure) - target$value
  }
  sol <- uniroot(f, interval, tol = 1e-5)
  p$eps_mean <- sol$root
  sim <- simulate_adoption(build_types(pop, p), shares, p, timing)
  list(params = p, sim = sim, cohorts = summarise_cohorts(sim), iterations = sol$iter)
}

# Joint calibration of km_sdlog (km ratio) and eps_mean (rebound) ----
calibrate_joint <- function(p, pop, shares, interval = c(0.05, 1)) {
  target <- p$km_ratio_target
  f <- function(km_sdlog) {
    p$km_sdlog <- km_sdlog
    res <- calibrate_eps(p, pop, shares)
    km_ratio(res$sim, target$year) - target$value
  }
  sol <- uniroot(f, interval, tol = 1e-3)
  p$km_sdlog <- sol$root
  calibrate_eps(p, pop, shares)
}

# Baseline ----
pop <- draw_population(params)
tcat("Calibrating baseline (km_sdlog and eps_mean)")
results <- list(baseline = calibrate_joint(params, pop, shares))

# Scenarios ----
# Each scenario matches the share path and the rebound target (eps_mean recalibrated).
scenarios <- list(
  baseline      = list(changes = list(), timing = "selection", joint = TRUE),
  no_climate    = list(changes = list(psi_mean = 0), timing = "selection", joint = TRUE),
  random_timing = list(changes = list(), timing = "random", joint = FALSE)
)
for (s in setdiff(names(scenarios), "baseline")) {
  tcat("Calibrating scenario ", s)
  p <- modifyList(results$baseline$params, scenarios[[s]]$changes)
  results[[s]] <- if (scenarios[[s]]$joint) {
    calibrate_joint(p, pop, shares)
  } else {
    calibrate_eps(p, pop, shares, scenarios[[s]]$timing)
  }
}
for (s in names(results)) {
  tcat(sprintf("  %-14s eps_mean = %.4f, km_sdlog = %.3f, km ratio %d = %.3f (target %.3f)",
               s, results[[s]]$params$eps_mean, results[[s]]$params$km_sdlog, params$km_ratio_target$year,
               km_ratio(results[[s]]$sim, params$km_ratio_target$year), params$km_ratio_target$value))
}

# Outputs ----
cohorts <- rbindlist(lapply(names(results), function(s) results[[s]]$cohorts[, scenario := s]))

base <- results$baseline
fit <- merge(
  shares,
  base$sim$agents[, .(n = .N), by = adopt_year][!is.na(adopt_year)][order(adopt_year)][
    , .(year = adopt_year, share_model = cumsum(n) / nrow(base$sim$agents))],
  by = "year"
)

# Rebound by percentile of the adoption gain (all households): the selection gradient
gain_curve <- base$sim$agents[, .(gain_pct = frank(-gain) / .N, rebound_log, rebound_km_pct = km_ev / km_ice - 1)][
  , .(rebound_log = mean(rebound_log), rebound_pct = mean(rebound_km_pct)),
  by = .(gain_bin = ceiling(gain_pct * 100) / 100)
][order(gain_bin)]

# Mean km of BEVs in use relative to all cars, model and StatLine
km_fit <- rbindlist(lapply(names(results), function(s) {
  data.table(scenario = s, year = params$years,
             km_ratio_model = sapply(params$years, function(t) km_ratio(results[[s]]$sim, t)))
}))
km_fit <- merge(km_fit, statline[, .(year, km_ratio_statline = km_ratio)], by = "year", all.x = TRUE)

calibrated <- data.table(
  scenario = names(results),
  eps_mean = sapply(results, function(r) r$params$eps_mean),
  km_sdlog = sapply(results, function(r) r$params$km_sdlog),
  psi_mean = sapply(results, function(r) r$params$psi_mean),
  timing   = sapply(scenarios[names(results)], `[[`, "timing"),
  km_ratio = sapply(results, function(r) km_ratio(r$sim, params$km_ratio_target$year))
)

dir.create("output", showWarnings = FALSE)
fwrite(cohorts, "output/cohorts.csv")
fwrite(fit, "output/share_fit.csv")
fwrite(gain_curve, "output/gain_curve.csv")
fwrite(calibrated, "output/calibrated_params.csv")
fwrite(km_fit, "output/km_fit.csv")
saveRDS(list(params = params, calibrated = calibrated, cohorts = cohorts, fit = fit, gain_curve = gain_curve,
             km_fit = km_fit, thresholds = results$baseline$sim$thresholds),
        "output/results.rds")
tcat("Written output/")
print(calibrated)
print(cohorts[scenario == "baseline", .(cohort, n_adopters, threshold, rebound_log, eps, psi, home, km_ice)])
