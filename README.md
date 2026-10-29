# EV rebound across adoption cohorts

How does the rebound of ICEV-to-BEV switchers develop as the fleet electrifies? A diffusion
model in which households differ in their disutility from driving an ICEV. The model is
calibrated to the Dutch BEV share (CBS StatLine) and cohort rebound targets. The current
targets, 15 log points for the 2015 cohort and 0 for the 2025 cohort, are **fictitious
placeholders**.

- **Vignette**: [`vignettes/ev_rebound.md`](vignettes/ev_rebound.md) (renders on GitHub), also as
  [PDF](vignettes/ev_rebound.pdf)
- **Model specification**: [`docs/model.md`](docs/model.md)
- **Research plan and literature**: [`docs/model_plan.md`](docs/model_plan.md)

## Pipeline

Run from the repository root:

```sh
Rscript R/run_all.R
```

| Script | Does |
|---|---|
| `R/fetch_prices.R` | petrol and marginal household electricity prices from StatLine, written to `data/statline_prices.csv` |
| `R/fetch_statline.R` | BEV share of cars in use and mean km by fuel type from StatLine, written to `data/statline_bev_share.csv` |
| `R/params.R` | assumed parameters and calibration targets |
| `R/model.R` | population draws, types, adoption simulation, cohort summaries |
| `R/calibrate.R` | calibrates the threshold path, km elasticity and status sd, plus scenarios, written to `output/` |
| `R/plots.R` | figures in CPB house style with [ggcpb](https://github.com/joris-klingen/ggcpb), written to `vignettes/figures/` |
| `R/build_vignette.R` | renders `vignettes/ev_rebound.Rmd` to `vignettes/ev_rebound.md` and `vignettes/ev_rebound.pdf` |

## Requirements

R (≥ 4.1) with `data.table`, `jsonlite`, `ggplot2` (≥ 3.5.2), `rmarkdown`, `knitr` and
`ggcpb`, plus a LaTeX installation with `xelatex` for the PDF. Without the Rijksoverheid font, ggcpb uses its open source fallback, Source Sans 3.
Run under a UTF-8 locale (e.g. `LC_ALL=C.UTF-8`).
