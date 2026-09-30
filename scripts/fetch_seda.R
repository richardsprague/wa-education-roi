## fetch_seda.R -- download SEDA 6.0 admin-district means, long by grade x
## year x subject (cohort standardized, NAEP-linked), plus documentation,
## into data/raw/seda/.
## Bead roi-dhj; see notes/district-feasibility.md section 3.
##
## Source: Stanford Digital Repository, https://purl.stanford.edu/xh833nn4025
## Terms: SEDA Data Use Agreement (non-commercial; do not republish the data
## files in full or in part). Files stay under gitignored data/raw/seda/.
## Cite: Reardon, Ho, Shear, Fahle, saliba & Kalogrides (2025). Stanford
## Education Data Archive (Version 6.0). https://doi.org/10.25740/xh833nn4025

source(here::here("R", "00_config.R"))

STACKS <- "https://stacks.stanford.edu/file/druid:xh833nn4025/"
FILES  <- c("seda_admindist_long_cs_6.0.csv",
            "seda_codebook_admindist_6.0.xlsx",
            "SEDA_documentation_6.0.pdf")
DEST   <- here::here("data", "raw", "seda")

dir.create(DEST, recursive = TRUE, showWarnings = FALSE)
options(timeout = max(3600, getOption("timeout")))

for (f in FILES) {
  path <- file.path(DEST, f)
  if (file.exists(path)) { message("have ", f); next }
  message("downloading ", f)
  utils::download.file(paste0(STACKS, f), path, mode = "wb", quiet = TRUE)
}
