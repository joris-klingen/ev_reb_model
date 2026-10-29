# Diffusion model with heterogeneous ICEV disutility and selection on driving gains ----
# See docs/model.md for the equations. Functions:
#   draw_population()   fixed random draws (common random numbers across calibration steps)
#   build_types()       household types and status utility given parameters
#   costs()             cost per km of an ICEV (before psi) and an EV in a year, from p$prices
#   driving()           km, rebound and driving surplus gain of every household at a year's prices
#   premium_path()      parametric net EV premium F_t
#   simulate_premium()  smoothed adoption by year for a given premium path F_t
#   simulate_adoption() adoption by year matching an observed share path (random-timing benchmark)
#   summarise_cohorts() cohort means of rebound and type composition
#   km_ratio()          mean km of the BEV stock relative to all cars in use
# Simulations store for every household and cohort the adopted mass m_<year> (0/1 in the
# discrete simulation, a probability in the smoothed one); all summaries are mass weighted.
# Rebound and km of a cohort are evaluated at the prices of its switch year.

library(data.table)

# Draws ----
draw_population <- function(p) {
  set.seed(p$seed)
  n <- p$n_agents
  pop <- data.table(
    id     = seq_len(n),
    z_km   = rnorm(n),
    z_psi  = rnorm(n),
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
# k is the annual km at the ICEV cost of the base year (fuel price of base_year plus psi).
build_types <- function(pop, p) {
  dt <- copy(pop)
  stopifnot(p$eps > 0, p$eps < 1) # eps < 1 keeps the consumer surplus integral finite
  dt[, `:=`(
    k   = rlnorm_mean(z_km, p$km_mean, p$km_sdlog),
    psi = rlnorm_mean(z_psi, p$psi_mean, p$psi_sdlog),
    # Status utility of EV ownership: differs across households, does not affect driving.
    # It is scaled by status_weight() of the EV penetration in the simulations.
    status = p$g_sd * z_g
  )]
  dt[, c_ref := costs(p, p$base_year)$fuel + psi]
  dt[]
}

# Driving at the prices of a year ----
# Demand v(c) = k (c / c_ref)^(-eps). The EV cost per km includes a hassle cost ev_hassle
# (charging time, range), so a household with a low ICEV disutility can have a zero rebound. Returns per household: km with an ICEV and an EV, the
# log rebound of switching, and the present value of the driving surplus gain (integral of v
# from the EV to the ICEV cost, valued over the horizon at constant prices).
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
  gain_base <- driving(dt, p, p$base_year)$gain_drive + dt$status
  f_base <- uniroot(function(f) mean(plogis((gain_base - f) / tau)) - share_base,
                    range(gain_base), tol = 1e-6)$root
  set(dt, j = mass_col(p$base_year), value = plogis((gain_base - f_base) / tau))
  w <- 1 - dt[[mass_col(p$base_year)]] # mass not yet adopted

  out <- data.table(year = p$years, threshold = premium$premium, n_new = NA_real_, share_model = NA_real_)
  for (t in p$years) {
    s_prev <- 1 - mean(w)
    gain_t <- driving(dt, p, t)$gain_drive + dt$status * status_weight(s_prev, p)
    m <- w * dt[[paste0("rep_", t)]] * plogis((gain_t - premium[year == t, premium]) / tau)
    set(dt, j = mass_col(t), value = m)
    w <- w - m
    m_sum <- sum(m)
    s_t <- 1 - mean(w)
    out[year == t, `:=`(n_new = m_sum, share_model = s_t)]
  }
  list(agents = dt, thresholds = out)
}

# Adoption path matching an observed share path ----
# shares: data.table(year, share) with the BEV stock share after each year, including base_year.
# timing = "selection": in each year the replacing households with the highest gain adopt.
# timing = "random": adopters are drawn at random from the replacing households (no selection).
simulate_adoption <- function(types, shares, p, timing = c("selection", "random")) {
  timing <- match.arg(timing)
  dt <- copy(types)
  dt[, gain := driving(dt, p, p$base_year)$gain_drive + status]
  setorder(dt, -gain)
  n <- nrow(dt)
  dt[, adopt_year := NA_integer_]

  # Common random numbers for the random-timing draws, so calibration sees a smooth objective
  if (timing == "random") set.seed(p$seed + 1)

  n0 <- round(n * shares[year == p$base_year, share])
  rows0 <- if (timing == "selection") seq_len(n0) else sample.int(n, n0)
  set(dt, i = rows0, j = "adopt_year", value = p$base_year)

  thresholds <- data.table(year = p$years, threshold = NA_real_, n_new = NA_real_)
  for (t in p$years) {
    n_target <- round(n * shares[year == t, share])
    n_add <- n_target - dt[, sum(!is.na(adopt_year))]
    pool <- dt[, which(is.na(adopt_year) & get(paste0("rep_", t)))]
    if (n_add > length(pool)) stop(sprintf("Year %d: %d adopters needed but only %d households replace", t, n_add, length(pool)))
    n_add <- max(n_add, 0L)
    if (timing == "selection") {
      # Gain at the prices of year t, with status scaled by last year's EV penetration
      gain_t <- driving(dt[pool], p, t)$gain_drive + dt$status[pool] * status_weight(shares[year == t - 1, share], p)
      ord <- order(-gain_t)
      rows <- pool[ord][seq_len(n_add)]
      f_t <- if (n_add > 0) gain_t[ord][n_add] else NA_real_
    } else {
      rows <- pool[sample.int(length(pool), n_add)]
      f_t <- NA_real_
    }
    set(dt, i = rows, j = "adopt_year", value = t)
    thresholds[year == t, `:=`(threshold = f_t, n_new = n_add)]
  }
  for (y in c(p$base_year, p$years)) set(dt, j = mass_col(y), value = as.numeric(dt$adopt_year %in% y))
  list(agents = dt, thresholds = thresholds)
}

# Cohort summaries (mass weighted) ----
# rebound_log is evaluated at the prices of the cohort's switch year; rebound_const at the
# prices of the base year, so that the difference is the effect of price changes.
summarise_cohorts <- function(sim, p) {
  cohorts <- as.integer(sub("m_", "", grep("^m_", names(sim$agents), value = TRUE)))
  const <- driving(sim$agents, p, p$base_year)
  coh <- rbindlist(lapply(cohorts, function(y) {
    d <- driving(sim$agents, p, y)
    m <- sim$agents[[mass_col(y)]]
    data.table(
      cohort         = y,
      n_adopters     = sum(m),
      rebound_log    = sum(m * d$rebound_log) / sum(m),
      rebound_const  = sum(m * const$rebound_log) / sum(m),
      rebound_pct    = sum(m * (exp(d$rebound_log) - 1)) / sum(m),
      rebound_km_pct = sum(m * (d$km_ev - d$km_ice)) / sum(m * d$km_ice),
      psi            = sum(m * sim$agents$psi) / sum(m),
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
  d <- driving(sim$agents, p, t)
  (sum(e * d$km_ev) / sum(e)) / mean(e * d$km_ev + (1 - e) * d$km_ice)
}

# Mean rebound of a cohort at the prices of its switch year ----
cohort_rebound <- function(sim, p, cohort_year) {
  m <- sim$agents[[mass_col(cohort_year)]]
  sum(m * driving(sim$agents, p, cohort_year)$rebound_log) / sum(m)
}
