# Build the vignette from vignettes/ev_rebound.Rmd ----
# Run from the repository root after R/calibrate.R and R/plots.R: Rscript R/build_vignette.R
#   vignettes/ev_rebound.md   GitHub-rendered markdown (math and figures display on GitHub)
#   vignettes/ev_rebound.pdf  PDF (xelatex)

library(ggcpb)

tcat("Rendering vignettes/ev_rebound.md")
rmarkdown::render("vignettes/ev_rebound.Rmd", output_format = "github_document", quiet = TRUE)
unlink("vignettes/ev_rebound.html") # preview file written by github_document
tcat("Rendering vignettes/ev_rebound.pdf")
rmarkdown::render("vignettes/ev_rebound.Rmd", output_format = "pdf_document", quiet = TRUE)
tcat("Written vignettes/ev_rebound.md and vignettes/ev_rebound.pdf")
