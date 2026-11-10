# Diffusion model with two ICEV-disutility types and selection on driving gains ----
# See docs/model.md for the equations. Functions:
#   draw_population()   fixed random draws (common random numbers across calibration steps)
#   build_types()       household types and status utility given parameters
#   costs()             cost per km of an ICEV (before psi) and an EV in a year, from p$prices
#   driving()           km, rebound and driving surplus gain of every household at a year's prices
#   premium_path()      parametric net EV premium F_t
#   simulate_premium()  smoothed adoption by year for a given premium path F_t
#   random_timing()     benchmark without selection: adopters are a random sample
#   summarise_cohorts() cohort means of rebound and type composition
#   km_ratio()          mean km of the BEV stock relative to all cars in use
# ICEV disutility has two types: a share psi_share of "green" households with psi = psi_high,
# the rest psi = 0. Every simulated household appears once as each type, with population
# weight wt (psi_share or 1 - psi_share), which keeps all moments smooth in psi_share.
# Simulations store for every household and cohort the adopted mass m_<year> (a probability);
# all summaries are weighted by wt * mass. Rebound and km of a cohort are evaluated at the
# prices of its switch year.

library(data.table)

# Draws ----
draw_population <- function(p) {
  set.seed(p$seed)
  n <- p$n_agents
  pop <- data.table(
    id     = seq_len(n),
    z_km   = rnorm(n),
    z_g    = rnorm(n)
  )
  # Replacement events per year: an agent can only switch in a year it replaces its car
  for (t in p$years) set(pop, j = paste0("rep_", t), value = runif(n) < p$replace_rate)
  pop[]
}

# Lognormal with a given mean ----
rlnorm_mean <- function(z, mean, sdlog) mean * exp(sdlog * z - sdlog^2 / 2)

# Cost per km in a year: ICEV fuel cost (excluding psi) and EV charging cost ----
costs <- function(p, year) {
  idx <- match(year, p$prices$year)
  stopifnot(!anyNA(idx))
  pr <- p$prices[idx]
  list(
    fuel = p$fuel_l_per_km * pr$petrol,
    ev   = p$ev_kwh_per_km * (pr$electricity + p$charge_markup)
  )
}

# Types and status ----
# Each household appears twice: green (psi = psi_high, weight psi_share) and not green
# (psi = 0, weight 1 - psi_share). k is the annual km at the ICEV cost of the base year.
build_types <- function(pop, p) {
  stopifnot(p$eps > 0, p$eps < 1) # eps < 1 keeps the consumer surplus integral finite
  dt <- rbind(
    copy(pop)[, `:=`(green = TRUE, psi = p$psi_high, wt = p$psi_share)],
    copy(pop)[, `:=`(green = FALSE, psi = 0, wt = 1 - p$psi_share)]
  )
  dt[, `:=`(
    k = rlnorm_mean(z_km, p$km_mean, p$km_sdlog),
    # Status utility of EV ownership: differs across households, does not affect driving.
    # It is scaled by status_weight() of the EV penetration in the simulations.
    status = p$g_sd * z_g
  )]
  dt[, c_ref := costs(p, p$base_year)$fuel + psi]
  dt[]
}

# Driving at the prices of a year ----
# Demand v(c) = k (c / c_ref)^(-eps). The EV cost per km includes a hassle cost ev_hassle
# (charging time, range), so a household without ICEV disutility can have a zero rebound.
# Returns per household: km with an ICEV and an EV, the log rebound of switching, and the
# present value of the driving surplus gain (integral of v from the EV to the ICEV cost,
# valued over the horizon at constant prices).
driving <- function(dt, p, year) {
  cs <- costs(p, year)
  annuity <- sum((1 + p$disc)^-(seq_len(p$horizon)))
  c_ice <- cs$fuel + dt$psi
  c_ev <- cs$ev + p$ev_hassle # money cost plus the per-km hassle of driving an EV
  list(
    km_ice      = dt$k * (c_ice / dt$c_ref)^(-p$eps),
    km_ev       = dt$k * (c_ev / dt$c_ref)^(-p$eps),
    rebound_log = p$eps * log(c_ice / c_ev),
    gain_drive  = annuity * dt$k * dt$c_ref^p$eps / (1 - p$eps) * (c_ice^(1 - p$eps) - c_ev^(1 - p$eps))
  )
}

# Status weight: EV status fades as EVs become common, halving every status_halving_share ----
status_weight <- function(share, p) 0.5^(share / p$status_halving_share)

mass_col <- function(y) paste0("m_", y)

# Net EV premium: smooth decline plus known purchase subsidies (SEPP) ----
premium_path <- function(p) {
  data.table(year = p$years)[, `:=`(
    trend = p$F_inf + (p$F_0 - p$F_inf) * exp(-p$F_gamma * (year - min(p$years))),
    subsidy = p$sepp_weight * fcoalesce(p$sepp[as.character(year)], 0)
  )][, premium := trend - subsidy][]
}

# Smoothed adoption path for a given premium path ----
# A household that replaces its car in year t adopts with probability
# plogis((G_it - F_t) / smooth_tau), a smoothed version of the threshold rule G_it >= F_t that
# makes all moments continuous in the parameters. G_it is the driving gain at the prices of
# year t plus status weighted by the simulated share of the previous year. The initial stock
# (base_year) matches the observed share: households adopt with
# plogis((G_i - F_base) / smooth_tau) at base-year prices and full status, F_base solved.
simulate_premium <- function(types, premium, share_base, p) {
  dt <- copy(types)
  tau <- p$smooth_tau
  wt <- dt$wt / sum(dt$wt)
  gain_base <- driving(dt, p, p$base_year)$gain_drive + dt$status
  f_base <- uniroot(function(f) sum(wt * plogis((gain_base - f) / tau)) - share_base,
                    range(gain_base), tol = 1e-6)$root
  set(dt, j = mass_col(p$base_year), value = plogis((gain_base - f_base) / tau))
  w <- 1 - dt[[mass_col(p$base_year)]] # mass not yet adopted

  out <- data.table(year = p$years, threshold = premium$premium, share_model = NA_real_)
  for (t in p$years) {
    s_prev <- 1 - sum(wt * w)
    gain_t <- driving(dt, p, t)$gain_drive + dt$status * status_weight(s_prev, p)
    m <- w * dt[[paste0("rep_", t)]] * plogis((gain_t - premium[year == t, premium]) / tau)
    set(dt, j = mass_col(t), value = m)
    w <- w - m
    s_t <- 1 - sum(wt * w)
    out[year == t, share_model := s_t]
  }
  list(agents = dt, thresholds = out)
}

# Cohort summaries (weighted by population weight and adopted mass) ----
# rebound_log is evaluated at the prices of the cohort's switch year; rebound_const at the
# prices of the base year, so that the difference is the effect of price changes.
summarise_cohorts <- function(sim, p) {
  cohorts <- as.integer(sub("m_", "", grep("^m_", names(sim$agents), value = TRUE)))
  a <- sim$agents
  const <- driving(a, p, p$base_year)
  coh <- rbindlist(lapply(cohorts, function(y) {
    d <- driving(a, p, y)
    m <- a$wt * a[[mass_col(y)]]
    data.table(
      cohort         = y,
      n_adopters     = sum(m),
      rebound_log    = sum(m * d$rebound_log) / sum(m),
      rebound_const  = sum(m * const$rebound_log) / sum(m),
      rebound_km_pct = sum(m * (d$km_ev - d$km_ice)) / sum(m * d$km_ice),
      green          = sum(m * a$green) / sum(m),
      psi            = sum(m * a$psi) / sum(m),
      km_ice         = sum(m * d$km_ice) / sum(m)
    )
  }))
  coh <- merge(coh, sim$thresholds[, .(year, threshold)], by.x = "cohort", by.y = "year", all.x = TRUE)
  setorder(coh, cohort)
  coh[]
}

# Mean km of the BEV stock relative to all cars in use, in year t (at year-t prices) ----
km_ratio <- function(sim, p, t) {
  cols <- grep("^m_", names(sim$agents), value = TRUE)
  cols <- cols[as.integer(sub("m_", "", cols)) <= t]
  e <- Reduce(`+`, sim$agents[, ..cols])
  wt <- sim$agents$wt
  d <- driving(sim$agents, p, t)
  (sum(wt * e * d$km_ev) / sum(wt * e)) / (sum(wt * (e * d$km_ev + (1 - e) * d$km_ice)) / sum(wt))
}

# Mean rebound of a cohort at the prices of its switch year ----
cohort_rebound <- function(sim, p, cohort_year) {
  m <- sim$agents$wt * sim$agents[[mass_col(cohort_year)]]
  sum(m * driving(sim$agents, p, cohort_year)$rebound_log) / sum(m)
}

# Benchmark without selection ----
# Adopters are a random sample of the population, so every cohort has the population mean
# rebound at the prices of its switch year, and the BEV stock has the population mean km.
random_timing <- function(types, shares, p) {
  wt <- types$wt / sum(types$wt)
  years <- c(p$base_year, p$years)
  cohorts <- rbindlist(lapply(years, function(y) {
    d <- driving(types, p, y)
    const <- driving(types, p, p$base_year)
    data.table(
      cohort = y, n_adopters = NA_real_,
      rebound_log = sum(wt * d$rebound_log), rebound_const = sum(wt * const$rebound_log),
      rebound_km_pct = sum(wt * (d$km_ev - d$km_ice)) / sum(wt * d$km_ice),
      green = sum(wt * types$green), psi = sum(wt * types$psi), km_ice = sum(wt * d$km_ice),
      threshold = NA_real_
    )
  }))
  km <- sapply(p$years, function(t) {
    d <- driving(types, p, t)
    s <- shares[year == t, share]
    sum(wt * d$km_ev) / (s * sum(wt * d$km_ev) + (1 - s) * sum(wt * d$km_ice))
  })
  list(cohorts = cohorts, km_ratio = data.table(year = p$years, km_ratio_model = km))
}
