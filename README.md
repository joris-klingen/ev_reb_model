# EV rebound across adoption cohorts

How does the rebound of ICEV-to-BEV switchers develop as the fleet electrifies? A diffusion
model in which households differ in their disutility from driving an ICEV. The model is
calibrated to the Dutch BEV share (CBS StatLine) and a cohort
rebound target. The current target, 10 log points for the 2015 cohort, is a **fictitious
placeholder**.

- **Site** (for economists): `docs/index.html`, served by GitHub Pages from `/docs` on `main`
- **Model specification**: [`docs/model.md`](docs/model.md)
- **Research plan and literature**: [`docs/model_plan.md`](docs/model_plan.md)

## Pipeline

Run from the repository root:

```sh
Rscript R/run_all.R
```

| Script | Does |
|---|---|
| `R/fetch_statline.R` | BEV share of cars in use and mean km by fuel type from StatLine, written to `data/statline_bev_share.csv` |
| `R/params.R` | assumed parameters and calibration targets |
| `R/model.R` | population draws, types, adoption simulation, cohort summaries |
| `R/calibrate.R` | calibrates the threshold path, km elasticity and status sd, plus scenarios, written to `output/` |
| `R/plots.R` | figures in CPB house style with [ggcpb](https://github.com/joris-klingen/ggcpb), written to `docs/figures/` |
| `R/build_site.R` | renders `docs/index.Rmd` to `docs/index.html` |

## Requirements

R (≥ 4.1) with `data.table`, `jsonlite`, `ggplot2` (≥ 3.5.2), `rmarkdown`, `knitr` and
`ggcpb`. Without the Rijksoverheid font, ggcpb uses its open source fallback, Source Sans 3.
Run under a UTF-8 locale (e.g. `LC_ALL=C.UTF-8`).
