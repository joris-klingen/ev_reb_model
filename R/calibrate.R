# Calibrate the model by simulated method of moments ----
# The net EV premium is restricted to a smooth decline plus the known SEPP subsidy
# (see premium_path()), so the BEV share path is no longer matched by construction and
# informs the dispersion of the adoption gain.
# Estimated: eps, g_sd, psi_sdlog, F_0, F_inf, F_gamma, sepp_weight
# Moments:
#   BEV share of cars in use 2016-2026 (StatLine), relative deviations
#   rebound of the 2015 cohort = 10 log points (PLACEHOLDER, fictitious)
#   mean km of BEVs / all cars in use, 2024 (StatLine)
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
share_base <- shares[year == params$base_year, share]

# Moments ----
# Rebound and km ratio get a higher weight so that they are (almost) matched exactly.
moment_weight <- 5
simulate_moments <- function(p, pop) {
  sim <- simulate_premium(build_types(pop, p), premium_path(p), share_base, p)
  m <- merge(sim$thresholds[, .(year, share_model)], shares, by = "year")
  dev <- c(
    m[, share_model / share - 1],
    moment_weight * (cohort_rebound(sim, p$rebound_target$cohort, p$rebound_target$measure) / p$rebound_target$value - 1),
    moment_weight * (km_ratio(sim, p$km_ratio_target$year) / p$km_ratio_target$value - 1)
  )
  list(sim = sim, dev = dev, loss = sum(dev^2))
}

# Estimation ----
# Parameters in unit_params are estimated on the logit scale, all others in logs.
unit_params <- c("sepp_weight")
estimate <- function(p, pop, free, maxit = 1500) {
  unit <- free %in% unit_params
  to_p <- function(theta) {
    p[free] <- as.list(ifelse(unit, plogis(theta), exp(theta)))
    p
  }
  theta0 <- ifelse(unit, qlogis(unlist(p[free])), log(unlist(p[free])))
  obj <- function(theta) simulate_moments(to_p(theta), pop)$loss
  opt <- optim(theta0, obj, method = "Nelder-Mead", control = list(maxit = maxit, reltol = 1e-10))
  # Restart once from the solution to escape early simplex collapse
  opt <- optim(opt$par, obj, method = "Nelder-Mead", control = list(maxit = maxit, reltol = 1e-10))
  list(params = to_p(opt$par), loss = opt$value, convergence = opt$convergence)
}

free_all <- c("eps", "g_sd", "psi_sdlog", "F_0", "F_inf", "F_gamma", "sepp_weight")
pop_est <- draw_population(modifyList(params, list(n_agents = params$n_agents_est)))
pop <- draw_population(params)

# Baseline: heterogeneous ICEV disutility ----
tcat("Estimating baseline (", paste(free_all, collapse = ", "), ")")
est <- list(baseline = estimate(params, pop_est, free_all))

# Homogeneous ICEV disutility: same moments, psi_sdlog fixed at 0 ----
tcat("Estimating homogeneous_psi")
est$homogeneous_psi <- estimate(modifyList(est$baseline$params, list(psi_sdlog = 0)), pop_est, setdiff(free_all, "psi_sdlog"))

# The baseline nests the homogeneous case: restart the baseline from that solution with a small
# psi_sdlog and keep the better fit
tcat("Re-estimating baseline from the homogeneous solution")
alt <- estimate(modifyList(est$homogeneous_psi$params, list(psi_sdlog = 0.3)), pop_est, free_all)
if (alt$loss < est$baseline$loss) est$baseline <- alt

# Final simulations on the full population ----
results <- lapply(est, function(e) {
  m <- simulate_moments(e$params, pop)
  list(params = e$params, sim = m$sim, loss_est = e$loss, loss = m$loss, cohorts = summarise_cohorts(m$sim))
})

# Random timing: no selection, adopters drawn at random to match the share path ----
calibrate_eps <- function(p, pop, interval = c(0.005, 0.8)) {
  target <- p$rebound_target
  f <- function(eps) {
    p$eps <- eps
    sim <- simulate_adoption(build_types(pop, p), shares, p, "random")
    cohort_rebound(sim, target$cohort, target$measure) - target$value
  }
  p$eps <- uniroot(f, interval, tol = 1e-5)$root
  sim <- simulate_adoption(build_types(pop, p), shares, p, "random")
  list(params = p, sim = sim, loss_est = NA_real_, loss = NA_real_, cohorts = summarise_cohorts(sim))
}
tcat("Calibrating random_timing")
results$random_timing <- calibrate_eps(results$baseline$params, pop)

for (s in names(results)) {
  r <- results[[s]]
  tcat(sprintf("  %-15s loss = %.4f (est %.4f), eps = %.4f, g_sd = %6.0f, psi_sdlog = %.2f, F_0 = %6.0f, F_inf = %6.0f, F_gamma = %.3f, sepp_weight = %.2f, km ratio = %.3f",
               s, r$loss, r$loss_est, r$params$eps, r$params$g_sd, r$params$psi_sdlog, r$params$F_0, r$params$F_inf,
               r$params$F_gamma, r$params$sepp_weight, km_ratio(r$sim, params$km_ratio_target$year)))
}

# Outputs ----
cohorts <- rbindlist(lapply(names(results), function(s) results[[s]]$cohorts[, scenario := s]), fill = TRUE)

base <- results$baseline
fit <- rbindlist(lapply(c("baseline", "homogeneous_psi"), function(s) {
  merge(shares, results[[s]]$sim$thresholds[, .(year, share_model)], by = "year")[, scenario := s]
}))

# Rebound by percentile of the adoption gain (all households), with status at the latest penetration
share_last <- fit[scenario == "baseline" & year == max(year), share_model]
gain_curve <- base$sim$agents[, .(
  gain_pct = frank(-(gain_drive + status * status_weight(share_last, base$params))) / .N,
  rebound_log, rebound_km_pct = km_ev / km_ice - 1
)][
  , .(rebound_log = mean(rebound_log), rebound_pct = mean(rebound_km_pct)),
  by = .(gain_bin = ceiling(gain_pct * 100) / 100)
][order(gain_bin)]

# Mean km of BEVs in use relative to all cars, model and StatLine
km_fit <- rbindlist(lapply(names(results), function(s) {
  data.table(scenario = s, year = params$years,
             km_ratio_model = sapply(params$years, function(t) km_ratio(results[[s]]$sim, t)))
}))
km_fit <- merge(km_fit, statline[, .(year, km_ratio_statline = km_ratio)], by = "year", all.x = TRUE)

calibrated <- rbindlist(lapply(names(results), function(s) {
  r <- results[[s]]
  data.table(
    scenario = s, timing = if (s == "random_timing") "random" else "selection",
    loss = r$loss, eps = r$params$eps, g_sd = r$params$g_sd, psi_sdlog = r$params$psi_sdlog,
    F_0 = r$params$F_0, F_inf = r$params$F_inf, F_gamma = r$params$F_gamma, sepp_weight = r$params$sepp_weight,
    km_ratio = km_ratio(r$sim, params$km_ratio_target$year)
  )
}))

premium <- premium_path(base$params)

dir.create("output", showWarnings = FALSE)
fwrite(cohorts, "output/cohorts.csv")
fwrite(fit, "output/share_fit.csv")
fwrite(gain_curve, "output/gain_curve.csv")
fwrite(calibrated, "output/calibrated_params.csv")
fwrite(km_fit, "output/km_fit.csv")
fwrite(premium, "output/premium_path.csv")
saveRDS(list(params = params, calibrated = calibrated, cohorts = cohorts, fit = fit, gain_curve = gain_curve,
             km_fit = km_fit, premium = premium, thresholds = base$sim$thresholds),
        "output/results.rds")
tcat("Written output/")
print(calibrated)
print(fit)
print(cohorts[scenario == "baseline", .(cohort, n_adopters, rebound_log, psi, km_ice)])
