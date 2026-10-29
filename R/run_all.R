# Full pipeline: data, calibration, figures, site ----
# Run from the repository root: Rscript R/run_all.R

library(ggcpb)

tcat("Step 1/4: fetch StatLine")
source("R/fetch_statline.R", local = new.env())
source("R/fetch_prices.R", local = new.env())
tcat("Step 2/4: calibrate")
source("R/calibrate.R", local = new.env())
tcat("Step 3/4: figures")
source("R/plots.R", local = new.env())
tcat("Step 4/4: vignette")
source("R/build_vignette.R", local = new.env())
