## 04_build_panel.R -- assemble the analysis panel.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))
source(here::here("R", "01_fetch_naep.R"))
source(here::here("R", "02_fetch_finance.R"))
source(here::here("R", "03_price_adjust.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(zoo)
})

#' Interpolate finance variables onto NAEP assessment years.
#' F-33 is annual, NAEP is biennial and lags; we take the school year ending in
#' the NAEP spring administration, carrying the last observation forward at most
#' two years so that late NAEP years are not silently dropped.
align_finance_to_naep <- function(fin, naep_years = NAEP_YEARS) {
  fin |>
    dplyr::group_by(state) |>
    dplyr::group_modify(function(d, key) {
      full <- tibble::tibble(year = min(d$year):max(naep_years))
      d |>
        dplyr::right_join(full, by = "year") |>
        dplyr::arrange(year) |>
        dplyr::mutate(dplyr::across(
          where(is.numeric) & !dplyr::all_of("year"),
          ~ zoo::na.locf(.x, na.rm = FALSE, maxgap = 2)
        ))
    }) |>
    dplyr::ungroup() |>
    dplyr::filter(year %in% naep_years)
}

build_analysis_panel <- function(refresh = FALSE) {
  naep <- build_naep_panel(refresh = refresh) |>
    dplyr::rename(state = jurisdiction) |>
    dplyr::filter(!state %in% NON_STATES)

  fin <- build_finance_panel(refresh = refresh) |>
    tidy_finance() |>
    align_finance_to_naep()

  defl <- build_deflators(refresh = refresh)

  panel <- naep |>
    dplyr::inner_join(fin, by = c("state", "year")) |>
    deflate_pp(cols = c("rev_pp", "rev_state_pp", "rev_local_pp", "exp_pp"),
               deflators = defl) |>
    dplyr::filter(year >= PRE_START) |>
    dplyr::arrange(state, year)

  require_balanced(panel, "state", "year")
}

#' The donor pool: all states except the treated unit and the exclusion list.
donor_states <- function(panel) {
  setdiff(unique(panel$state), c(TREAT_UNIT, EXCLUDE_DONORS, NON_STATES))
}

if (sys.nframe() == 0) {
  p <- build_analysis_panel(refresh = TRUE)
  readr::write_csv(p, file.path(DIR_PROCESSED, "analysis_panel.csv"))
  cli::cli_alert_success(
    "Analysis panel: {nrow(p)} rows, {dplyr::n_distinct(p$state)} states, {dplyr::n_distinct(p$year)} years."
  )
}
