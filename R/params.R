# Model parameters ----
# Monetary values in euro, cost per km in euro/km. One agent is one car-owning household.
# Parameters marked CALIBRATED are set by R/calibrate.R. All others are assumptions (see docs/model.md).

params <- list(
  seed       = 20261027,
  n_agents   = 1e6,
  base_year  = 2015,      # stock of BEVs at the end of this year is the initial condition
  years      = 2016:2026, # adoption cohorts

  # Driving demand v_i(c) = k_i * (c / cI_i)^(-eps) ----
  km_mean    = 13000,     # mean annual km at the ICEV cost (CBS: ~12,300 for all cars in use)
  km_sdlog   = 0.55,      # dispersion of km
  eps        = 0.10,      # CALIBRATED: price elasticity of km, common to all households (rebound target)

  # Cost per km ----
  c_fuel     = 0.12,      # ICEV fuel cost per km (about 6.5 l/100 km at 1.85 euro/l)
  psi_mean   = 0.02,      # mean disutility per km of driving an ICEV (climate, ...)
  psi_sdlog  = 1.50,      # heterogeneity in the ICEV disutility: the key assumption
  c_ev       = 0.06,      # EV cost per km (mix of home and public charging, about 0.35 euro/kWh)

  # Adoption ----
  g_sd         = 15000,   # CALIBRATED: sd of a lump-sum EV taste (warm glow, model fit), PV euro; no effect on driving
  replace_rate = 0.12,    # annual probability of replacing the car (EV adoption only at replacement)
  horizon      = 8,       # years over which the km cost saving is valued
  disc         = 0.04,    # discount rate

  # Calibration targets ----
  # PLACEHOLDER: fictitious value, to be replaced by the register-data estimate per cohort
  rebound_target = list(cohort = 2015, value = 0.10, measure = "log"), # 2015 cohort: all adopters up to 2015
  # Mean km of BEVs in use relative to all cars in use (StatLine 85405NED), value read from the data
  km_ratio_target = list(year = 2024)
)
