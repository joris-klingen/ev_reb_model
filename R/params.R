# Model parameters ----
# Monetary values in euro, cost per km in euro/km. One agent is one car-owning household.
# Parameters marked CALIBRATED are set by R/calibrate.R. All others are assumptions (see docs/model.md).

params <- list(
  seed       = 20261027,
  n_agents   = 2e5,       # population for the final simulation
  n_agents_est = 5e4,     # smaller population for the moment search
  base_year  = 2015,      # stock of BEVs at the end of this year is the initial condition
  years      = 2016:2026, # adoption cohorts

  # Driving demand v_i(c) = k_i * (c / cI_i)^(-eps) ----
  km_mean    = 13000,     # mean annual km at the base-year ICEV cost (CBS: ~12,300 for all cars in use)
  km_sdlog   = 0.55,      # dispersion of km
  eps        = 0.15,      # CALIBRATED: price elasticity of km, common to all households (rebound target)

  # Cost per km ----
  # Annual prices (data/statline_prices.csv) are added as params$prices by R/calibrate.R
  fuel_l_per_km = 0.065,  # ICEV fuel use (6.5 l/100 km)
  ev_kwh_per_km = 0.17,   # EV electricity use
  charge_markup = 0.12,   # euro/kWh on top of the marginal household price: mix of home and public charging
  ev_hassle  = 0.06,      # CALIBRATED: hassle cost per EV km (charging time, range), euro/km
  # ICEV disutility per km (climate, ...), the key heterogeneity: a share psi_share of "green"
  # households has psi = psi_high, the rest psi = 0
  psi_share  = 0.01,      # CALIBRATED
  psi_high   = 0.25,      # CALIBRATED, euro/km

  # Net EV premium F_t = F_inf + (F_0 - F_inf) * exp(-F_gamma * (t - 2016)) - sepp_weight * SEPP_t (PV euro) ----
  F_0        = 40000,     # CALIBRATED
  F_inf      = 7000,      # CALIBRATED
  F_gamma    = 0.20,      # CALIBRATED
  # SEPP purchase subsidy for private BEV buyers (RVO), euro per car, and its pass-through
  # into the net premium (budget caps, private buyers only)
  sepp       = c(`2020` = 4000, `2021` = 4000, `2022` = 3350, `2023` = 2950, `2024` = 2950),
  sepp_weight = 0.2,      # CALIBRATED

  # Adoption ----
  smooth_tau   = 1000,    # smoothing of the adoption rule in the simulation (euro), small relative to g_sd
  g_sd         = 10000,   # CALIBRATED: sd of the status utility of EV ownership, dispersed across households, PV euro; no effect on driving
  status_halving_share = 0.10, # EV status halves with every 10 %-points of BEV share (assumption)
  replace_rate = 0.12,    # annual probability of replacing the car (EV adoption only at replacement)
  horizon      = 8,       # years over which the km cost saving is valued
  disc         = 0.04,    # discount rate

  # Calibration targets ----
  # PLACEHOLDER: fictitious values (log points), to be replaced by register-data estimates per cohort.
  # Cohort 2015 = all adopters up to 2015.
  rebound_targets = data.frame(cohort = c(2015, 2025), value = c(0.15, 0.00)),
  # Mean km of BEVs in use relative to all cars in use (StatLine 85405NED), value read from the data
  km_ratio_target = list(year = 2024)
)
