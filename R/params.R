# Model parameters ----
# Monetary values in euro, cost per km in euro/km. One agent is one car-owning household.
# Parameters marked CALIBRATED are set by R/calibrate.R. All others are assumptions (see docs/model.md).

params <- list(
  seed       = 20261027,
  n_agents   = 1e6,
  base_year  = 2015,      # stock of BEVs at the end of this year is the initial condition
  years      = 2016:2026, # adoption cohorts

  # Driving demand v_i(c) = k_i * (c / cI_i)^(-eps_i) ----
  km_mean    = 13000,     # mean annual km at the ICEV cost (CBS: ~12,300 for all cars in use)
  km_sdlog   = 0.55,
  eps_mean   = 0.10,      # CALIBRATED: mean price elasticity of km (rebound target)
  eps_sdlog  = 0.60,
  eps_max    = 0.95,      # eps < 1 keeps the consumer surplus integral finite

  # Cost per km ----
  c_fuel     = 0.12,      # ICEV fuel cost per km (about 6.5 l/100 km at 1.85 euro/l)
  psi_mean   = 0.02,      # mean per-km climate disutility of driving an ICEV
  psi_sdlog  = 1.00,
  c_home     = 0.04,      # EV cost per km with home charging (about 0.24 euro/kWh at 0.17 kWh/km)
  c_public   = 0.09,      # EV cost per km with public charging (about 0.55 euro/kWh)
  home_share = 0.60,      # share of households with home charging

  # Adoption ----
  g_sd         = 3000,    # CALIBRATED: sd of the lump-sum EV taste shock (warm glow, range, model fit), PV euro
  replace_rate = 0.12,    # annual probability of replacing the car (EV adoption only at replacement)
  horizon      = 8,       # years over which the km cost saving is valued
  disc         = 0.04,    # discount rate

  # Calibration targets ----
  # PLACEHOLDER: fictitious value, to be replaced by the register-data estimate per cohort
  rebound_target = list(cohort = 2020, value = 0.10, measure = "log"),
  # Mean km of BEVs in use relative to all cars in use (StatLine 85405NED), value read from the data
  km_ratio_target = list(year = 2024)
)
