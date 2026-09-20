## 03_price_adjust.R -- convert nominal dollars into comparable purchasing power.
##
## Two adjustments, applied in sequence:
##   1. Time: CPI-U (FRED series CPIAUCSL, annual mean) -> constant dollars.
##   2. Place: BEA Regional Price Parities (RPP), all items, by state.
##
## A note on the choice of place-deflator. The methodologically preferred
## instrument is NCES's Comparable Wage Index for Teachers (CWIFT), because it
## deflates by the wages of *comparable college-educated non-teachers* in the
## same labor market -- which is what a school district actually competes
## against. CWIFT is not served by a stable API; download it manually and drop
## it in data/raw/cwift.csv and this script will prefer it over RPP.
##   https://nces.ed.gov/programs/edge/economic/

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(httr2)
})

#' Annual CPI-U from FRED's public CSV endpoint (no key required).
#'
#' FRED gates this endpoint on User-Agent: it serves curl's default UA over
#' both HTTP/1.1 and HTTP/2, but hangs on any custom UA, which surfaces in R as
#' either "HTTP/2 stream not closed cleanly" or a bare timeout. Verified
#' 2026-09-20 by holding the protocol fixed and varying only the UA. So we
#' fetch through httr2 with a curl-style UA rather than readr's URL reader.
fetch_cpi <- function(refresh = FALSE) {
  cache_rds("cpi_u", refresh = refresh, expr = {
    url <- "https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL"
    resp <- httr2::request(url) |>
      httr2::req_user_agent("curl/8.7.1") |>
      httr2::req_retry(max_tries = 3, backoff = ~ 2^.x) |>
      httr2::req_timeout(60) |>
      httr2::req_perform()
    raw <- readr::read_csv(I(httr2::resp_body_string(resp)), show_col_types = FALSE)
    if (ncol(raw) != 2) {
      cli::cli_abort("FRED returned {ncol(raw)} columns; expected 2 (date, value).")
    }
    names(raw) <- c("date", "cpi")
    raw |>
      dplyr::mutate(year = as.integer(format(as.Date(date), "%Y"))) |>
      dplyr::group_by(year) |>
      dplyr::summarise(cpi = mean(cpi, na.rm = TRUE), .groups = "drop")
  })
}

#' BEA Regional Price Parities by state, from BEA's public regional archive.
fetch_rpp <- function(refresh = FALSE) {
  cache_rds("bea_rpp", refresh = refresh, expr = {
    zip_url  <- "https://apps.bea.gov/regional/zip/SARPP.zip"
    zip_path <- file.path(DIR_RAW, "SARPP.zip")
    if (!file.exists(zip_path)) {
      utils::download.file(zip_url, zip_path, mode = "wb", quiet = FALSE)
    }
    files <- utils::unzip(zip_path, list = TRUE)$Name
    ## BEA names this member by table and coverage span, e.g.
    ## "SARPP_STATE_2008_2024.csv" -- not "SARPP1". The span moves each
    ## release, so match the stem and let the years float.
    target <- grep("^SARPP_STATE.*\\.csv$", files, value = TRUE)[1]
    if (is.na(target)) {
      cli::cli_abort(c(
        "Could not find the SARPP1 table inside {.path SARPP.zip}.",
        "i" = "Files present: {.val {files}}"
      ))
    }
    utils::unzip(zip_path, files = target, exdir = DIR_RAW, overwrite = TRUE)
    readr::read_csv(file.path(DIR_RAW, target), show_col_types = FALSE)
  })
}

#' Prefer a manually supplied CWIFT file if the analyst has provided one.
load_cwift <- function() {
  path <- file.path(DIR_RAW, "cwift.csv")
  if (!file.exists(path)) return(NULL)
  cli::cli_alert_success("Using CWIFT from {.path data/raw/cwift.csv}")
  readr::read_csv(path, show_col_types = FALSE)
}

#' Extend the place index backward to cover pre-treatment years.
#'
#' BEA RPP begins in 2008, but the panel starts at PRE_START (2003), and three
#' of the five pre-treatment NAEP years (2003, 2005, 2007) fall before RPP
#' coverage. Without this, build_deflators()'s join silently drops those years
#' and fit_synth() is left with two pre-periods and aborts.
#'
#' We carry each state's earliest observed index backward. Relative state price
#' levels are highly persistent -- Alabama moves only 88.9 to 89.1 across
#' 2008-2024 -- so this is a mild assumption, but it IS an assumption about
#' three of five pre-treatment periods. Rows so filled are flagged
#' `place_imputed` so downstream code and the methodology notes can see them.
backfill_place_index <- function(place, first_year = PRE_START) {
  earliest <- min(place$year, na.rm = TRUE)
  place <- dplyr::mutate(place, place_imputed = FALSE)
  if (first_year >= earliest) return(place)

  base <- place |>
    dplyr::filter(year == earliest) |>
    dplyr::select(state, place_index)

  filler <- tidyr::expand_grid(
    year = seq.int(first_year, earliest - 1L),
    base
  ) |>
    dplyr::mutate(place_imputed = TRUE)

  cli::cli_alert_warning(
    "Place index carried back from {earliest} to cover {first_year}-{earliest - 1L}."
  )

  dplyr::bind_rows(place, filler) |>
    dplyr::arrange(state, year)
}

#' Build a state-year deflator table: real dollars in BASE_YEAR, cost-adjusted.
build_deflators <- function(base_year = 2019L, refresh = FALSE) {
  cpi <- fetch_cpi(refresh = refresh)
  base_cpi <- cpi$cpi[cpi$year == base_year]

  cwift <- load_cwift()

  place <- if (!is.null(cwift)) {
    require_cols(cwift, c("state", "year", "cwift"), "CWIFT file")
    cwift |> dplyr::transmute(state, year = as.integer(year), place_index = cwift)
  } else {
    rpp <- fetch_rpp(refresh = refresh)
    ## BEA ships this table in wide form: one row per GeoName x LineCode,
    ## one column per year. Reshape defensively rather than assuming positions.
    year_cols <- grep("^(19|20)[0-9]{2}$", names(rpp), value = TRUE)
    require_cols(rpp, c("GeoName", "LineCode"), "BEA SARPP1")
    rpp |>
      dplyr::filter(LineCode == 1) |>            # 1 = RPPs: All items
      dplyr::select(GeoName, dplyr::all_of(year_cols)) |>
      tidyr::pivot_longer(dplyr::all_of(year_cols),
                          names_to = "year", values_to = "place_index") |>
      dplyr::mutate(
        year = as.integer(year),
        place_index = suppressWarnings(as.numeric(place_index)) / 100,
        state = state.abb[match(GeoName, state.name)]
      ) |>
      dplyr::filter(!is.na(state)) |>
      dplyr::select(state, year, place_index)
  }

  place <- backfill_place_index(place, first_year = PRE_START)

  cpi |>
    dplyr::mutate(time_deflator = base_cpi / cpi) |>
    dplyr::select(year, time_deflator) |>
    dplyr::inner_join(place, by = "year") |>
    dplyr::mutate(base_year = base_year)
}

#' Apply both deflators to a per-pupil dollar column.
#' Real, cost-adjusted dollars = nominal * (CPI_base / CPI_t) / place_index
deflate_pp <- function(df, cols, deflators) {
  df |>
    dplyr::inner_join(deflators, by = c("state", "year")) |>
    dplyr::mutate(dplyr::across(
      dplyr::all_of(cols),
      ~ .x * time_deflator / place_index,
      .names = "{.col}_real"
    ))
}
