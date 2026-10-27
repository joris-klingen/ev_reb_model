# Diffusion model with heterogeneous ICEV disutility and selection on driving gains ----
# See docs/model.md for the equations. Functions:
#   draw_population()   fixed random draws (common random numbers across calibration steps)
#   build_types()       types, rebound and adoption gain given parameters
#   simulate_adoption() adoption by year, matching an observed stock share path
#   summarise_cohorts() cohort means of rebound and type composition
#   km_ratio()          mean km of the BEV stock relative to all cars in use

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
  # ownership, which differs across households and does not affect driving (smooths selection)
  dt[, gain := annuity * dcs + p$g_sd * z_g]
  dt[]
}

# Adoption path ----
# shares: data.table(year, share) with the BEV stock share after each year, including base_year.
# timing = "selection": in each year the replacing households with the highest gain adopt,
#   the implied threshold F_t is the gain of the marginal adopter (rank/probit model).
# timing = "random": adopters are drawn at random from the replacing households (no selection,
#   the benchmark of an epidemic/Bass model where timing is unrelated to type).
simulate_adoption <- function(types, shares, p, timing = c("selection", "random")) {
  timing <- match.arg(timing)
  dt <- copy(types)
  setorder(dt, -gain)
  n <- nrow(dt)
  dt[, adopt_year := NA_integer_]

  # Common random numbers for the random-timing draws, so calibration sees a smooth objective
  if (timing == "random") set.seed(p$seed + 1)

  # Initial stock: the highest-gain households (random households under random timing)
  n0 <- round(n * shares[year == p$base_year, share])
  rows0 <- if (timing == "selection") seq_len(n0) else sample.int(n, n0)
  set(dt, i = rows0, j = "adopt_year", value = p$base_year)

  thresholds <- data.table(year = p$years, threshold = NA_real_, n_new = NA_integer_, pool = NA_integer_)
  for (t in p$years) {
    n_target <- round(n * shares[year == t, share])
    n_add <- n_target - dt[, sum(!is.na(adopt_year))]
    pool <- dt[, which(is.na(adopt_year) & get(paste0("rep_", t)))]
    if (n_add > length(pool)) stop(sprintf("Year %d: %d adopters needed but only %d households replace", t, n_add, length(pool)))
    n_add <- max(n_add, 0L)
    rows <- if (timing == "selection") pool[seq_len(n_add)] else pool[sample.int(length(pool), n_add)]
    set(dt, i = rows, j = "adopt_year", value = t)
    f_t <- if (timing == "selection" && n_add > 0) dt$gain[rows[n_add]] else NA_real_
    n_pool <- length(pool)
    thresholds[year == t, `:=`(threshold = f_t, n_new = n_add, pool = n_pool)]
  }
  list(agents = dt, thresholds = thresholds)
}

# Cohort summaries ----
summarise_cohorts <- function(sim) {
  coh <- sim$agents[!is.na(adopt_year), .(
    n_adopters      = .N,
    rebound_log     = mean(rebound_log),
    rebound_pct     = mean(exp(rebound_log) - 1),
    rebound_km_pct  = sum(km_ev - km_ice) / sum(km_ice),
    psi             = mean(psi),
    km_ice          = mean(km_ice),
    gain            = mean(gain)
  ), by = .(cohort = adopt_year)]
  coh <- merge(coh, sim$thresholds, by.x = "cohort", by.y = "year", all.x = TRUE)
  setorder(coh, cohort)
  coh[]
}

# Mean km of the BEV stock relative to all cars in use, in year t ----
km_ratio <- function(sim, t) {
  sim$agents[, {
    ev <- !is.na(adopt_year) & adopt_year <= t
    mean(km_ev[ev]) / mean(fifelse(ev, km_ev, km_ice))
  }]
}

cohort_rebound <- function(sim, cohort_year, measure = c("log", "pct", "km_pct")) {
  measure <- match.arg(measure)
  col <- switch(measure, log = "rebound_log", pct = "rebound_pct", km_pct = "rebound_km_pct")
  summarise_cohorts(sim)[cohort == cohort_year, get(col)]
}
