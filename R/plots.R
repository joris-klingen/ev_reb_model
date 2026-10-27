# Figures in CPB house style (ggcpb), written to vignettes/figures for the vignette ----
# Run from the repository root after R/calibrate.R: Rscript R/plots.R
# Uses the open source fallback font of ggcpb (Source Sans 3) when Rijksoverheid Sans is not installed.

library(data.table)
library(ggplot2)
library(ggcpb)

options(ggcpb.style = "english", ggcpb.font_warning = FALSE)

res <- readRDS("output/results.rds")
dir.create("vignettes/figures", recursive = TRUE, showWarnings = FALSE)
years <- res$params$years

scenario_labels <- c(
  baseline        = "Heterogeneous ICEV disutility",
  homogeneous_psi = "Homogeneous ICEV disutility",
  random_timing   = "Random timing (no selection)"
)
year_axis <- scale_x_continuous(breaks = seq(2015, 2025, 2))
add_years <- function(p) suppressMessages(p + year_axis)

save_fig <- function(p, name, page = "full", height = 3.4) {
  suppressMessages(save_cpb(file.path("vignettes/figures", paste0(name, ".png")), p, page = page, height = height))
  tcat("Written vignettes/figures/", name, ".png")
}

# BEV share: StatLine vs model ----
share <- rbind(
  res$fit[scenario == "baseline", .(year, value = share, series = "StatLine")],
  res$fit[, .(year, value = share_model, series = scenario_labels[scenario])]
)
share[, `:=`(
  series = factor(series, c("StatLine", scenario_labels[c("baseline", "homogeneous_psi")])),
  value = 100 * value
)]
p <- cpb_line(share, x = year, y = value, colour = series, points = TRUE,
              title = "BEV share of passenger cars in use",
              ylab = "% of cars in use") |> add_years()
save_fig(p, "fig_share")

# Estimated net EV premium ----
prem <- melt(res$premium[, .(year, `Trend` = trend / 1000, `Including SEPP subsidy` = premium / 1000)],
             id.vars = "year", variable.name = "series", value.name = "value")
p <- cpb_line(prem, x = year, y = value, colour = series, points = TRUE,
              title = "Estimated net EV premium",
              ylab = "thousand euro (PV)") |> add_years()
save_fig(p, "fig_premium")

coh <- res$cohorts # cohort 2015 = all adopters up to 2015

# Composition of cohorts ----
comp <- coh[scenario == "baseline", .(
  cohort,
  `ICEV disutility per km` = psi,
  `Pre-switch km` = km_ice
)]
comp <- melt(comp, id.vars = "cohort", variable.name = "series", value.name = "value")
comp[, value := 100 * value / value[cohort == 2015], by = series]
p <- cpb_line(comp, x = cohort, y = value, colour = series, points = TRUE,
              title = "Who switches: mean type per cohort",
              ylab = "index (cohort up to 2015 = 100)") |> add_years()
save_fig(p, "fig_composition")

# Cohort rebound per scenario ----
scen <- coh[, .(cohort, rebound = 100 * rebound_log, scenario = factor(scenario_labels[scenario], scenario_labels))]
p <- cpb_line(scen, x = cohort, y = rebound, colour = scenario, points = TRUE,
              value_limits = c(0, 16),
              title = "Rebound per adoption cohort",
              ylab = "change in km after switching, log points x 100") |> add_years()
save_fig(p, "fig_rebound_cohort", height = 3.6)

# Selection gradient: rebound by rank of the adoption gain ----
gc <- res$gain_curve[, .(rank = 100 * gain_bin, rebound = 100 * rebound_log)]
share_2026 <- 100 * res$fit[scenario == "baseline" & year == max(year), share_model]
p <- suppressMessages(cpb_line(gc, x = rank, y = rebound,
              title = "Rebound by rank of the adoption gain",
              ylab = "potential rebound, log points x 100",
              xlab = "% of households with a higher gain") +
  scale_x_continuous(breaks = seq(0, 100, 20), limits = c(0, 100), expand = c(0, 0)) +
  geom_vline(xintercept = share_2026, linetype = "dashed", linewidth = 0.4, colour = cpb_cols(2)) +
  annotate("text", x = share_2026, y = max(gc$rebound), label = "BEV stock 2026",
           hjust = -0.1, vjust = 1, size = 2.2, colour = cpb_cols(2), family = cpb_font_family()))
save_fig(p, "fig_gain_curve")

# Km of BEVs relative to all cars: StatLine vs model ----
km <- res$km_fit[scenario %in% c("baseline", "random_timing") & !is.na(km_ratio_statline)]
km <- rbind(
  km[scenario == "baseline", .(year, value = km_ratio_statline, series = "StatLine")],
  km[, .(year, value = km_ratio_model, series = scenario_labels[scenario])]
)
km[, series := factor(series, c("StatLine", scenario_labels[c("baseline", "random_timing")]))]
p <- cpb_line(km, x = year, y = value, colour = series, points = TRUE,
              value_limits = c(0.5, 3.5),
              title = "Mean km of BEVs relative to all cars in use",
              ylab = "ratio (target: StatLine 2024)") |> add_years()
save_fig(p, "fig_km_ratio")
