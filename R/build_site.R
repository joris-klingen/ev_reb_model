# Build the GitHub Pages site and the PDF vignette from docs/index.Rmd ----
# Run from the repository root after R/calibrate.R and R/plots.R: Rscript R/build_site.R
#   docs/index.html     site (math as MathML, rendered natively by the browser)
#   docs/ev_rebound.pdf vignette (xelatex)

library(ggcpb)

tcat("Rendering docs/index.html")
rmarkdown::render("docs/index.Rmd", output_format = "html_document", output_file = "index.html", quiet = TRUE)
tcat("Rendering docs/ev_rebound.pdf")
rmarkdown::render("docs/index.Rmd", output_format = "pdf_document", output_file = "ev_rebound.pdf", quiet = TRUE)
tcat("Written docs/index.html and docs/ev_rebound.pdf")
