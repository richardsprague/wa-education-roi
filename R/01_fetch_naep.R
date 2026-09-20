## 01_fetch_naep.R -- pull state-level NAEP mean scale scores.
##
## Source: NAEP Data Service (NCES), no API key required.
##   https://www.nationsreportcard.gov/Dataservice/GetAdhocData.aspx
##
## NOTE: the Data Service is an undocumented-but-public endpoint. The query
## string below follows NCES's own published examples, but if NCES changes the
## response shape this is the first script that will break. The validation step
## in tests/test_anchors.R exists precisely to catch a silent shape change.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))

suppressPackageStartupMessages({
  library(httr2)
  library(purrr)
  library(tidyr)
})

NAEP_BASE <- "https://www.nationsreportcard.gov/Dataservice/GetAdhocData.aspx"

#' Fetch NAEP mean scale scores for a set of jurisdictions and years.
#'
#' @param subject "mathematics" or "reading"
#' @param grade   4 or 8
#' @param jurisdictions character vector of NAEP jurisdiction codes.
#'   Two-letter USPS codes for states; "NP" = national public.
#' @param years numeric vector of assessment years
fetch_naep <- function(subject = OUTCOME_SUBJECT,
                       grade = OUTCOME_GRADE,
                       jurisdictions,
                       years = NAEP_YEARS) {

  stopifnot(subject %in% names(NAEP_SUBSCALE))

  req <- httr2::request(NAEP_BASE) |>
    httr2::req_url_query(
      type         = "data",
      subject      = subject,
      grade        = grade,
      subscale     = unname(NAEP_SUBSCALE[[subject]]),
      variable     = "TOTAL",
      jurisdiction = paste(jurisdictions, collapse = ","),
      stattype     = "MN:MN",
      Year         = paste(years, collapse = ",")
    ) |>
    httr2::req_user_agent("wa-education-roi (research; contact: richardsprague.com)") |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2^.x) |>
    httr2::req_timeout(90)

  resp <- httr2::req_perform(req)

  ## The service returns JSON with a small envelope; it has historically been
  ## served as text/plain, so parse explicitly rather than trusting the header.
  txt <- httr2::resp_body_string(resp)
  parsed <- jsonlite::fromJSON(txt, simplifyVector = TRUE)

  if (!is.null(parsed$status) && !identical(as.integer(parsed$status), 200L)) {
    cli::cli_abort("NAEP Data Service returned status {parsed$status}.")
  }

  res <- parsed$result
  if (is.null(res) || !nrow(res)) {
    cli::cli_abort("NAEP Data Service returned no rows for this query.")
  }

  require_cols(res, c("year", "jurisdiction", "value"), "NAEP Data Service")

  tibble::as_tibble(res) |>
    dplyr::transmute(
      jurisdiction = as.character(jurisdiction),
      year         = as.integer(year),
      subject      = subject,
      grade        = as.integer(grade),
      score        = suppressWarnings(as.numeric(value)),
      error_flag   = if ("errorFlag" %in% names(res)) errorFlag else NA
    ) |>
    dplyr::filter(!is.na(score)) |>
    dplyr::arrange(jurisdiction, year)
}

#' All 50 states plus national public, for the configured outcome.
build_naep_panel <- function(refresh = FALSE) {
  juris <- c(state.abb, "NP")
  cache_rds(
    key = sprintf("naep_%s_g%d", OUTCOME_SUBJECT, OUTCOME_GRADE),
    expr = fetch_naep(jurisdictions = juris),
    refresh = refresh
  )
}

if (sys.nframe() == 0) {
  panel <- build_naep_panel(refresh = TRUE)
  readr::write_csv(panel, file.path(DIR_PROCESSED, "naep_panel.csv"))
  cli::cli_alert_success("Wrote {nrow(panel)} NAEP rows.")
}
