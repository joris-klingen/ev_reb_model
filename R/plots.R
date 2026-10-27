# Figures in CPB house style (ggcpb), written to docs/figures for the GitHub Pages site ----
# Run from the repository root after R/calibrate.R: Rscript R/plots.R
# Uses the open source fallback font of ggcpb (Source Sans 3) when Rijksoverheid Sans is not installed.

library(data.table)
library(ggplot2)
library(ggcpb)

options(ggcpb.style = "english", ggcpb.font_warning = FALSE)

res <- readRDS("output/results.rds")
dir.create("docs/figures", recursive = TRUE, showWarnings = FALSE)
years <- res$params$years

scenario_labels <- c(
  baseline        = "Baseline (selection)",
  sharp_selection = "Sharper selection (taste sd / 2)",
  noisy_selection = "Noisier selection (taste sd x 2)",
  no_climate      = "No climate disutility",
  random_timing   = "Random timing (no selection)"
)
year_axis <- scale_x_continuous(breaks = seq(2016, 2026, 2))
add_years <- function(p) suppressMessages(p + year_axis)

save_fig <- function(p, name, page = "full", height = 3.4) {
  suppressMessages(save_cpb(file.path("docs/figures", paste0(name, ".png")), p, page = page, height = height))
  tcat("Written docs/figures/", name, ".png")
}

# BEV share: StatLine vs model ----
share <- melt(res$fit, id.vars = "year", measure.vars = c("share", "share_model"),
              variable.name = "series", value.name = "value")
share[, `:=`(
  series = factor(series, c("share", "share_model"), c("StatLine (target)", "Model")),
  value = 100 * value
)]
p <- cpb_line(share[year >= 2016], x = year, y = value, colour = series, points = TRUE,
              title = "BEV share of passenger cars in use",
              ylab = "% of cars in use") |> add_years()
save_fig(p, "fig_share")

# Implied threshold ----
thr <- res$thresholds[, .(year, threshold = threshold / 1000)]
p <- cpb_line(thr, x = year, y = threshold, points = TRUE,
              title = "Implied adoption threshold F(t)",
              ylab = "gain of the marginal adopter, thousand euro (PV)") |> add_years()
save_fig(p, "fig_threshold")

# Cohort rebound: selection vs random timing ----
coh <- res$cohorts[cohort >= 2016]
reb <- coh[scenario %in% c("baseline", "random_timing"),
           .(cohort, rebound = 100 * rebound_log, scenario = factor(scenario_labels[scenario], scenario_labels))]
p <- cpb_line(reb, x = cohort, y = rebound, colour = scenario, points = TRUE,
              value_limits = c(0, 14),
              title = "Rebound per adoption cohort",
              ylab = "change in km after switching, log points x 100") |> add_years()
save_fig(p, "fig_rebound_cohort")

# Composition of cohorts ----
comp <- coh[scenario == "baseline", .(
  cohort,
  `Pre-switch km` = km_ice,
  `Km elasticity` = eps,
  `Climate disutility per km` = psi,
  `Log cost ratio ICEV/EV` = cost_ratio_log,
  `Home charging share` = home
)]
comp <- melt(comp, id.vars = "cohort", variable.name = "series", value.name = "value")
comp[, value := 100 * value / value[cohort == 2016], by = series]
p <- cpb_line(comp, x = cohort, y = value, colour = series, points = TRUE, legend_ncol = 2,
              title = "Who switches: mean type per cohort",
              ylab = "index (2016 cohort = 100)") |> add_years()
save_fig(p, "fig_composition", height = 3.9)

# Scenarios ----
scen <- coh[, .(cohort, rebound = 100 * rebound_log, scenario = factor(scenario_labels[scenario], scenario_labels))]
p <- cpb_line(scen, x = cohort, y = rebound, colour = scenario, legend_ncol = 2,
              value_limits = c(0, 16),
              title = "Rebound per cohort under alternative assumptions",
              ylab = "change in km after switching, log points x 100") |> add_years()
save_fig(p, "fig_scenarios", height = 3.9)

# Selection gradient: rebound by rank of the adoption gain ----
gc <- res$gain_curve[, .(rank = 100 * gain_bin, rebound = 100 * rebound_log)]
share_2026 <- 100 * res$fit[year == max(year), share]
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
