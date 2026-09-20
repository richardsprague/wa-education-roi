## 02_fetch_finance.R -- state-level K-12 revenue and current expenditure per pupil.
##
## Source: Urban Institute Education Data Portal, which serves the Census F-33 /
## NCES CCD school district finance survey. No API key required.
##   https://educationdata.urban.org/documentation/
##
## We aggregate district-level finance to the state level rather than using a
## published state table, so that the enrollment denominator and the expenditure
## numerator come from the same universe of districts in the same year.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))

suppressPackageStartupMessages({
  library(educationdata)
  library(dplyr)
  library(tidyr)
})

## F-33 lags NAEP; the portal's coverage ends a couple of years short of the
## current NAEP administration. Adjust upward as Urban publishes new years.
FINANCE_YEARS <- 2003:2022

#' Pull one year of district finance and collapse to state totals.
fetch_finance_year <- function(year) {
  df <- educationdata::get_education_data(
    level  = "school-districts",
    source = "ccd",
    topic  = "finance",
    filters = list(year = year)
  )

  require_cols(
    df,
    c("fips", "year", "rev_total", "exp_current_instruction", "enrollment_fall_responsible"),
    sprintf("Urban CCD finance %d", year)
  )

  df |>
    ## Urban encodes missing/suppressed values as negative sentinels (-1, -2, -3).
    ## any_of() rather than c() so a year missing an optional field does not abort.
    dplyr::mutate(dplyr::across(
      dplyr::any_of(c("rev_total", "rev_state_total", "rev_local_total",
                      "rev_fed_total", "exp_total", "exp_current_instruction",
                      "enrollment_fall_responsible")),
      ~ dplyr::if_else(as.numeric(.x) < 0, NA_real_, as.numeric(.x))
    )) |>
    dplyr::group_by(fips, year) |>
    dplyr::summarise(
      enrollment  = sum(enrollment_fall_responsible, na.rm = TRUE),
      rev_total   = sum(rev_total, na.rm = TRUE),
      rev_state   = sum(rev_state_total, na.rm = TRUE),
      rev_local   = sum(rev_local_total, na.rm = TRUE),
      rev_federal = sum(rev_fed_total, na.rm = TRUE),
      exp_total   = sum(exp_total, na.rm = TRUE),
      .groups = "drop"
    )
}

build_finance_panel <- function(years = FINANCE_YEARS, refresh = FALSE) {
  cache_rds(
    key = "ccd_finance_state",
    expr = purrr::map_dfr(years, function(y) {
      cli::cli_alert_info("CCD finance: {y}")
      fetch_finance_year(y)
    }),
    refresh = refresh
  )
}

#' Attach USPS abbreviations and compute per-pupil measures.
tidy_finance <- function(df) {
  fips_lookup <- tibble::tibble(
    fips = as.integer(c(1,2,4,5,6,8,9,10,11,12,13,15,16,17,18,19,20,21,22,23,24,
                        25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,
                        44,45,46,47,48,49,50,51,53,54,55,56)),
    state = c("AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID",
              "IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO",
              "MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA",
              "RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY")
  )

  df |>
    dplyr::mutate(fips = as.integer(fips)) |>
    dplyr::inner_join(fips_lookup, by = "fips") |>
    dplyr::filter(enrollment > 0) |>
    dplyr::mutate(
      rev_pp       = rev_total / enrollment,
      rev_state_pp = rev_state / enrollment,
      rev_local_pp = rev_local / enrollment,
      exp_pp       = exp_total / enrollment,
      ## Share of revenue coming from the state -- the variable that actually
      ## moved under McCleary's levy swap.
      state_share  = rev_state / rev_total
    ) |>
    dplyr::select(state, year, enrollment, dplyr::ends_with("_pp"), state_share)
}

if (sys.nframe() == 0) {
  fin <- build_finance_panel(refresh = TRUE) |> tidy_finance()
  readr::write_csv(fin, file.path(DIR_PROCESSED, "finance_panel.csv"))
  cli::cli_alert_success("Wrote {nrow(fin)} finance rows.")
}
