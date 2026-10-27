# Diffusion model with heterogeneous ICEV disutility and selection on driving gains ----
# See docs/model.md for the equations. Functions:
#   draw_population()   fixed random draws (common random numbers across calibration steps)
#   build_types()       types, rebound and adoption gain given parameters
#   premium_path()      parametric net EV premium F_t
#   simulate_premium()  smoothed adoption by year for a given premium path F_t
#   simulate_adoption() adoption by year matching an observed share path (random-timing benchmark)
#   summarise_cohorts() cohort means of rebound and type composition
#   km_ratio()          mean km of the BEV stock relative to all cars in use
# Simulations store for every household and cohort the adopted mass m_<year> (0/1 in the
# discrete simulation, a probability in the smoothed one); all summaries are mass weighted.

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

# Types, rebound and gain ----
build_types <- function(pop, p) {
  dt <- copy(pop)
  annuity <- sum((1 + p$disc)^-(seq_len(p$horizon)))
  stopifnot(p$eps > 0, p$eps < 1) # eps < 1 keeps the consumer surplus integral finite
  dt[, `:=`(
    k   = rlnorm_mean(z_km, p$km_mean, p$km_sdlog),
    psi = rlnorm_mean(z_psi, p$psi_mean, p$psi_sdlog)
  )]
  dt[, c_ice := p$c_fuel + psi]
  dt[, `:=`(
    # Log rebound: ln v(c_ev) - ln v(c_ice)
    rebound_log = p$eps * log(c_ice / p$c_ev),
    km_ice      = k,
    km_ev       = k * (p$c_ev / c_ice)^(-p$eps),
    # Annual consumer surplus gain: integral of v(c) from c_ev to c_ice
    dcs         = k * c_ice / (1 - p$eps) * (1 - (p$c_ev / c_ice)^(1 - p$eps))
  )]
  # Adoption gain: present value of the surplus from cheaper km, plus the status utility of EV
  # ownership, which differs across households and does not affect driving.
  # Status is scaled by status_weight() of the EV penetration in the simulations;
  # gain is the gain at zero penetration.
  dt[, `:=`(gain_drive = annuity * dcs, status = p$g_sd * z_g)]
  dt[, gain := gain_drive + status]
  dt[]
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
# makes all moments continuous in the parameters. The initial stock (base_year) matches the
# observed share: households adopt with plogis((G_i - F_base) / smooth_tau), F_base solved.
# Status is weighted by the simulated share of the previous year.
simulate_premium <- function(types, premium, share_base, p) {
  dt <- copy(types)
  tau <- p$smooth_tau
  f_base <- uniroot(function(f) mean(plogis((dt$gain - f) / tau)) - share_base,
                    range(dt$gain), tol = 1e-6)$root
  set(dt, j = mass_col(p$base_year), value = plogis((dt$gain - f_base) / tau))
  w <- 1 - dt[[mass_col(p$base_year)]] # mass not yet adopted

  out <- data.table(year = p$years, threshold = premium$premium, n_new = NA_real_, share_model = NA_real_)
  for (t in p$years) {
    s_prev <- 1 - mean(w)
    gain_t <- dt[, gain_drive + status * status_weight(s_prev, p)]
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
    # Gain in year t, with status scaled by last year's EV penetration
    gain_t <- dt[pool, gain_drive + status * status_weight(shares[year == t - 1, share], p)]
    ord <- order(-gain_t)
    pool <- pool[ord]
    gain_t <- gain_t[ord]
    if (n_add > length(pool)) stop(sprintf("Year %d: %d adopters needed but only %d households replace", t, n_add, length(pool)))
    n_add <- max(n_add, 0L)
    rows <- if (timing == "selection") pool[seq_len(n_add)] else pool[sample.int(length(pool), n_add)]
    set(dt, i = rows, j = "adopt_year", value = t)
    f_t <- if (timing == "selection" && n_add > 0) gain_t[n_add] else NA_real_
    thresholds[year == t, `:=`(threshold = f_t, n_new = n_add)]
  }
  for (y in c(p$base_year, p$years)) set(dt, j = mass_col(y), value = as.numeric(dt$adopt_year %in% y))
  list(agents = dt, thresholds = thresholds)
}

# Cohort summaries (mass weighted) ----
summarise_cohorts <- function(sim) {
  cohorts <- as.integer(sub("m_", "", grep("^m_", names(sim$agents), value = TRUE)))
  coh <- rbindlist(lapply(cohorts, function(y) {
    sim$agents[, {
      m <- get(mass_col(y))
      .(
        cohort         = y,
        n_adopters     = sum(m),
        rebound_log    = sum(m * rebound_log) / sum(m),
        rebound_pct    = sum(m * (exp(rebound_log) - 1)) / sum(m),
        rebound_km_pct = sum(m * (km_ev - km_ice)) / sum(m * km_ice),
        psi            = sum(m * psi) / sum(m),
        km_ice         = sum(m * km_ice) / sum(m),
        gain           = sum(m * gain) / sum(m)
      )
    }]
  }))
  coh <- merge(coh, sim$thresholds[, .(year, threshold)], by.x = "cohort", by.y = "year", all.x = TRUE)
  setorder(coh, cohort)
  coh[]
}

# Mean km of the BEV stock relative to all cars in use, in year t ----
km_ratio <- function(sim, t) {
  cols <- grep("^m_", names(sim$agents), value = TRUE)
  cols <- cols[as.integer(sub("m_", "", cols)) <= t]
  sim$agents[, {
    e <- Reduce(`+`, .SD)
    (sum(e * km_ev) / sum(e)) / mean(e * km_ev + (1 - e) * km_ice)
  }, .SDcols = cols]
}

cohort_rebound <- function(sim, cohort_year, measure = c("log", "pct", "km_pct")) {
  measure <- match.arg(measure)
  sim$agents[, {
    m <- get(mass_col(cohort_year))
    switch(measure,
      log    = sum(m * rebound_log) / sum(m),
      pct    = sum(m * (exp(rebound_log) - 1)) / sum(m),
      km_pct = sum(m * (km_ev - km_ice)) / sum(m * km_ice)
    )
  }]
}
