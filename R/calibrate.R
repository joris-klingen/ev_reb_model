# Calibrate the model by simulated method of moments ----
# The net EV premium is restricted to a smooth decline plus the known SEPP subsidy
# (see premium_path()), so the BEV share path is not matched by construction and informs the
# dispersion of the adoption gain.
# Estimated: eps, g_sd, psi_share, psi_high, ev_hassle, F_0, F_inf, F_gamma, sepp_weight
# Moments:
#   BEV share of cars in use 2016-2026 (StatLine), relative deviations
#   rebound per cohort 2015-2025, linear from 15 to 0 log points (PLACEHOLDER, fictitious),
#   absolute deviations scaled by 10 log points, weight 2 each
#   mean km of BEVs / all cars in use, 2024 (StatLine)
# Costs per km follow the annual petrol and electricity prices (data/statline_prices.csv).
# Run from the repository root: Rscript R/calibrate.R

library(data.table)
library(ggcpb)

source("R/params.R")
source("R/model.R")

# Data ----
params$prices <- fread("data/statline_prices.csv")[, .(year, petrol, electricity)]
stopifnot(all(c(params$base_year, params$years) %in% params$prices$year))
statline <- fread("data/statline_bev_share.csv")
shares <- statline[, .(year, share = bev_share)]
stopifnot(all(c(params$base_year, params$years) %in% shares$year))
params$km_ratio_target$value <- statline[year == params$km_ratio_target$year, km_ratio]
share_base <- shares[year == params$base_year, share]

# Moments ----
# The km ratio gets a high weight so that it is (almost) matched exactly; each of the 11 rebound
# moments gets a moderate weight.
moment_weight <- 5
rebound_weight <- 2
simulate_moments <- function(p, pop) {
  sim <- simulate_premium(build_types(pop, p), premium_path(p), share_base, p)
  m <- merge(sim$thresholds[, .(year, share_model)], shares, by = "year")
  dev <- c(
    m[, share_model / share - 1],
    rebound_weight * (sapply(p$rebound_targets$cohort, function(y) cohort_rebound(sim, p, y)) - p$rebound_targets$value) / 0.10,
    moment_weight * (km_ratio(sim, p, p$km_ratio_target$year) / p$km_ratio_target$value - 1)
  )
  list(sim = sim, dev = dev, loss = sum(dev^2))
}

# Estimation ----
# Parameters in unit_params are estimated on the logit scale, all others in logs.
unit_params <- c("eps", "sepp_weight", "psi_share")
estimate <- function(p, pop, free, maxit = 1500) {
  unit <- free %in% unit_params
  to_p <- function(theta) {
    p[free] <- as.list(ifelse(unit, plogis(theta), exp(theta)))
    p
  }
  theta0 <- unlist(p[free])
  theta0 <- ifelse(unit, qlogis(pmin(theta0, 1 - 1e-9)), log(theta0))
  obj <- function(theta) simulate_moments(to_p(theta), pop)$loss
  opt <- optim(theta0, obj, method = "Nelder-Mead", control = list(maxit = maxit, reltol = 1e-10))
  # Restart once from the solution to escape early simplex collapse
  opt <- optim(opt$par, obj, method = "Nelder-Mead", control = list(maxit = maxit, reltol = 1e-10))
  list(params = to_p(opt$par), loss = opt$value, convergence = opt$convergence)
}

free_all <- c("eps", "g_sd", "psi_share", "psi_high", "ev_hassle", "F_0", "F_inf", "F_gamma", "sepp_weight")
pop_est <- draw_population(modifyList(params, list(n_agents = params$n_agents_est)))
pop <- draw_population(params)

# Each estimation is cached in output/estimates/, so a rerun only redoes missing steps.
# Delete that folder after changing the model, moments or starting values.
dir.create("output/estimates", recursive = TRUE, showWarnings = FALSE)
cached_estimate <- function(name, ...) {
  file <- file.path("output/estimates", paste0(name, ".rds"))
  if (file.exists(file)) {
    tcat("Using cached estimate ", file)
    return(readRDS(file))
  }
  tcat("Estimating ", name)
  e <- estimate(...)
  saveRDS(e, file)
  tcat(sprintf("  %s: loss = %.4f", name, e$loss))
  e
}

# Baseline: two ICEV-disutility types ----
est <- list(baseline = cached_estimate("baseline", params, pop_est, free_all))

# Homogeneous ICEV disutility: every household has psi_high (psi_share fixed at 1) ----
est$homogeneous_psi <- cached_estimate("homogeneous_psi",
  modifyList(est$baseline$params, list(psi_share = 1, psi_high = 0.02)), pop_est, setdiff(free_all, "psi_share"))

# Final simulations on the full population ----
results <- lapply(est, function(e) {
  m <- simulate_moments(e$params, pop)
  list(params = e$params, sim = m$sim, loss_est = e$loss, loss = m$loss, cohorts = summarise_cohorts(m$sim, e$params))
})

# Random timing: no selection; eps set so that the first rebound target is met ----
tcat("Calibrating random_timing")
p_rt <- results$baseline$params
target <- p_rt$rebound_targets[1, ]
f_rt <- function(eps) {
  p_rt$eps <- eps
  random_timing(build_types(pop, p_rt), shares, p_rt)$cohorts[cohort == target$cohort, rebound_log] - target$value
}
p_rt$eps <- if (f_rt(0.95) < 0) 0.95 else uniroot(f_rt, c(0.005, 0.95), tol = 1e-5)$root
rt <- random_timing(build_types(pop, p_rt), shares, p_rt)

for (s in names(results)) {
  r <- results[[s]]
  tcat(sprintf("  %-15s loss = %.4f (est %.4f), eps = %.4f, g_sd = %6.0f, psi_share = %.3f, psi_high = %.3f, ev_hassle = %.3f, F_0 = %6.0f, F_inf = %6.0f, F_gamma = %.3f, sepp_weight = %.2f, km ratio = %.3f",
               s, r$loss, r$loss_est, r$params$eps, r$params$g_sd, r$params$psi_share, r$params$psi_high,
               r$params$ev_hassle, r$params$F_0, r$params$F_inf, r$params$F_gamma, r$params$sepp_weight,
               km_ratio(r$sim, r$params, params$km_ratio_target$year)))
}
tcat(sprintf("  random_timing   eps = %.4f", p_rt$eps))

# Outputs ----
cohorts <- rbind(
  rbindlist(lapply(names(results), function(s) results[[s]]$cohorts[, scenario := s])),
  rt$cohorts[, scenario := "random_timing"],
  fill = TRUE
)

base <- results$baseline
fit <- rbindlist(lapply(names(results), function(s) {
  merge(shares, results[[s]]$sim$thresholds[, .(year, share_model)], by = "year")[, scenario := s]
}))

# Rebound by rank of the adoption gain (population weighted), at the latest prices and penetration
share_last <- fit[scenario == "baseline" & year == max(year), share_model]
d_last <- driving(base$sim$agents, base$params, max(params$years))
gain_curve <- data.table(
  gain = d_last$gain_drive + base$sim$agents$status * status_weight(share_last, base$params),
  wt = base$sim$agents$wt,
  rebound_log = d_last$rebound_log, rebound_km_pct = d_last$km_ev / d_last$km_ice - 1
)[order(-gain)][, gain_pct := cumsum(wt) / sum(wt)][
  , .(rebound_log = sum(wt * rebound_log) / sum(wt), rebound_pct = sum(wt * rebound_km_pct) / sum(wt)),
  by = .(gain_bin = ceiling(gain_pct * 100) / 100)
][order(gain_bin)]

# Mean km of BEVs in use relative to all cars, model and StatLine
km_fit <- rbind(
  rbindlist(lapply(names(results), function(s) {
    data.table(scenario = s, year = params$years,
               km_ratio_model = sapply(params$years, function(t) km_ratio(results[[s]]$sim, results[[s]]$params, t)))
  })),
  rt$km_ratio[, scenario := "random_timing"]
)
km_fit <- merge(km_fit, statline[, .(year, km_ratio_statline = km_ratio)], by = "year", all.x = TRUE)

calibrated <- rbind(
  rbindlist(lapply(names(results), function(s) {
    r <- results[[s]]
    data.table(
      scenario = s, timing = "selection",
      loss = r$loss, eps = r$params$eps, g_sd = r$params$g_sd,
      psi_share = r$params$psi_share, psi_high = r$params$psi_high, ev_hassle = r$params$ev_hassle,
      F_0 = r$params$F_0, F_inf = r$params$F_inf, F_gamma = r$params$F_gamma, sepp_weight = r$params$sepp_weight,
      km_ratio = km_ratio(r$sim, r$params, params$km_ratio_target$year)
    )
  })),
  data.table(scenario = "random_timing", timing = "random", eps = p_rt$eps),
  fill = TRUE
)

premium <- premium_path(base$params)

# Cost per km of an ICEV (fuel only) and an EV, and their log ratio ----
cost_path <- params$prices[year %in% c(params$base_year, params$years)][, `:=`(
  cost_ice = costs(params, year)$fuel,
  cost_ev  = costs(params, year)$ev,
  cost_ev_hassle = costs(params, year)$ev + base$params$ev_hassle
)][, `:=`(log_ratio = log(cost_ice / cost_ev), log_ratio_hassle = log(cost_ice / cost_ev_hassle))][]

dir.create("output", showWarnings = FALSE)
fwrite(cohorts, "output/cohorts.csv")
fwrite(fit, "output/share_fit.csv")
fwrite(gain_curve, "output/gain_curve.csv")
fwrite(calibrated, "output/calibrated_params.csv")
fwrite(km_fit, "output/km_fit.csv")
fwrite(premium, "output/premium_path.csv")
fwrite(cost_path, "output/cost_path.csv")
saveRDS(list(params = params, calibrated = calibrated, cohorts = cohorts, fit = fit, gain_curve = gain_curve,
             km_fit = km_fit, premium = premium, cost_path = cost_path, thresholds = base$sim$thresholds),
        "output/results.rds")
tcat("Written output/")
print(calibrated)
print(fit)
print(cost_path)
print(cohorts[scenario == "baseline", .(cohort, n_adopters, rebound_log, rebound_const, green, km_ice)])
