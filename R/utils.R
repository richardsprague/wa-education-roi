## utils.R -- small helpers shared across the pipeline.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(cli)
})

#' Cache the result of an expensive expression to an RDS file.
#'
#' @param key   cache filename stem
#' @param expr  expression to evaluate on a cache miss
#' @param dir   cache directory
#' @param refresh force re-evaluation
cache_rds <- function(key, expr, dir = DIR_RAW, refresh = FALSE) {
  path <- file.path(dir, paste0(key, ".rds"))
  if (file.exists(path) && !refresh) {
    cli::cli_alert_info("cache hit: {.path {basename(path)}}")
    return(readRDS(path))
  }
  cli::cli_alert_info("cache miss: fetching {.val {key}}")
  val <- force(expr)
  saveRDS(val, path)
  val
}

#' Assert that a data frame contains the expected columns, with a message that
#' tells the user what to do when an upstream API renames a field.
require_cols <- function(df, cols, source_label) {
  missing <- setdiff(cols, names(df))
  if (length(missing)) {
    cli::cli_abort(c(
      "{source_label} is missing expected column{?s}: {.field {missing}}.",
      "i" = "The upstream schema may have changed.",
      "i" = "Columns actually returned: {.field {names(df)}}",
      "i" = "Fix the mapping in the corresponding R/0*_fetch_*.R script."
    ))
  }
  invisible(df)
}

#' Require a balanced panel: every unit observed in every period.
require_balanced <- function(df, unit = "state", time = "year") {
  tab <- table(df[[unit]])
  n_t <- length(unique(df[[time]]))
  bad <- names(tab)[tab != n_t]
  if (length(bad)) {
    cli::cli_warn(c(
      "Panel is unbalanced; dropping {length(bad)} unit{?s}: {.val {bad}}",
      "i" = "Synthetic control requires a balanced donor pool."
    ))
    df <- dplyr::filter(df, !.data[[unit]] %in% bad)
  }
  df
}
