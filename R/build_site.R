# Build the GitHub Pages site docs/index.html from docs/index.Rmd ----
# Run from the repository root after R/calibrate.R and R/plots.R: Rscript R/build_site.R

library(ggcpb)

tcat("Rendering docs/index.Rmd")
rmarkdown::render("docs/index.Rmd", output_file = "index.html", quiet = TRUE)
tcat("Written docs/index.html")
