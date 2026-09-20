## test_anchors.R -- validate the API pull against hand-verified published figures.
##
## Rationale: every number in data/cache/naep_verified_anchors.csv was read off a
## published NCES/OSPI/SBE document, not off the API. If the Data Service query
## silently changes meaning (different subscale, different jurisdiction coding,
## accommodations-permitted vs not), these assertions fail loudly instead of the
## analysis quietly running on the wrong series.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))
source(here::here("R", "01_fetch_naep.R"))

suppressPackageStartupMessages({
  library(testthat)
  library(dplyr)
  library(readr)
})

anchors <- readr::read_csv(
  file.path(DIR_CACHE, "naep_verified_anchors.csv"),
  show_col_types = FALSE
)

test_that("NAEP API matches published figures within rounding tolerance", {
  subjects <- unique(anchors[c("subject", "grade")])

  for (i in seq_len(nrow(subjects))) {
    subj  <- subjects$subject[i]
    grade <- subjects$grade[i]

    want <- dplyr::filter(anchors, subject == subj, grade == !!grade)

    got <- fetch_naep(
      subject = subj,
      grade = grade,
      jurisdictions = unique(want$jurisdiction),
      years = unique(want$year)
    )

    joined <- dplyr::inner_join(
      want, got,
      by = c("jurisdiction", "year", "subject", "grade"),
      suffix = c("_published", "_api")
    )

    expect_equal(nrow(joined), nrow(want),
                 info = "API did not return every anchor row")

    expect_true(
      all(abs(joined$score_published - joined$score_api) <= 1.0),
      info = paste0(
        "Mismatch vs published figures:\n",
        paste(utils::capture.output(print(
          dplyr::filter(joined, abs(score_published - score_api) > 1.0)
        )), collapse = "\n")
      )
    )
  }
})

test_that("panel is balanced and donor pool is non-trivial", {
  source(here::here("R", "04_build_panel.R"))
  p <- build_analysis_panel()
  expect_gt(length(donor_states(p)), 20)
  expect_true(TREAT_UNIT %in% p$state)
})
