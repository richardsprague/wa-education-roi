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
fetch_cpi <- function(refresh = FALSE) {
  cache_rds("cpi_u", refresh = refresh, expr = {
    url <- "https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL"
    raw <- readr::read_csv(url, show_col_types = FALSE)
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
    target <- grep("SARPP1", files, value = TRUE)[1]
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
