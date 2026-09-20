## 05_synth.R -- synthetic control estimation.
##
## Design:
##   Treated unit : WA
##   Treatment    : McCleary funding response, onset dated to 2013
##   Outcome      : NAEP grade 8 math mean scale score
##   Predictors   : pre-period outcome levels + real, cost-adjusted per-pupil
##                  revenue + state share of revenue
##
## Inference is placebo-based (Abadie, Diamond & Hainmueller 2010): we re-run
## the estimator treating each donor as if it were treated, and locate WA's
## post/pre RMSPE ratio in that distribution. With five pre-periods this is a
## weak test and we report it as such.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))

suppressPackageStartupMessages({
  library(tidysynth)
  library(dplyr)
  library(ggplot2)
})

#' Fit the synthetic control for a given outcome column.
#'
#' @param panel analysis panel from build_analysis_panel()
#' @param outcome_col bare column name of the outcome
#' @param treat_year treatment onset
fit_synth <- function(panel,
                      outcome_col = "score",
                      treat_year = TREAT_YEAR,
                      donors = NULL) {

  if (is.null(donors)) donors <- donor_states(panel)

  df <- panel |>
    dplyr::filter(state %in% c(TREAT_UNIT, donors)) |>
    dplyr::rename(outcome = dplyr::all_of(outcome_col))

  pre_years <- sort(unique(df$year[df$year < treat_year]))
  if (length(pre_years) < 3) {
    cli::cli_abort("Need at least 3 pre-treatment periods; got {length(pre_years)}.")
  }

  out <- df |>
    tidysynth::synthetic_control(
      outcome = outcome,
      unit    = state,
      time    = year,
      i_unit  = TREAT_UNIT,
      i_time  = treat_year,
      generate_placebos = TRUE
    ) |>
    ## Pre-period mean of the outcome.
    tidysynth::generate_predictor(
      time_window = pre_years,
      outcome_pre_mean = mean(outcome, na.rm = TRUE)
    ) |>
    ## Resources, in real cost-adjusted dollars.
    tidysynth::generate_predictor(
      time_window = pre_years,
      rev_pp_pre_mean = mean(rev_pp_real, na.rm = TRUE),
      state_share_pre_mean = mean(state_share, na.rm = TRUE)
    )

  ## Individual pre-period outcome lags, which is what actually drives fit.
  for (y in pre_years) {
    nm <- paste0("outcome_", y)
    out <- tidysynth::generate_predictor(
      out,
      time_window = y,
      !!nm := mean(outcome, na.rm = TRUE)
    )
  }

  out |>
    tidysynth::generate_weights(optimization_window = pre_years) |>
    tidysynth::generate_control()
}

#' Tidy summary of the treatment effect path.
synth_effects <- function(sc) {
  sc |>
    tidysynth::grab_synthetic_control() |>
    dplyr::mutate(gap = real_y - synth_y)
}

#' Placebo inference: WA's RMSPE ratio and its rank among donors.
synth_inference <- function(sc) {
  sig <- tidysynth::grab_significance(sc)
  wa <- dplyr::filter(sig, unit_name == TREAT_UNIT)
  list(
    table = sig,
    rmspe_ratio = wa$mspe_ratio,
    rank = wa$rank,
    p_value = wa$fishers_exact_pvalue
  )
}

#' Run the full estimation for both the outcome and the first stage.
run_all <- function(panel) {
  cli::cli_h2("Outcome: NAEP grade 8 math")
  sc_score <- fit_synth(panel, "score")

  cli::cli_h2("First stage: real cost-adjusted revenue per pupil")
  sc_money <- fit_synth(panel, "rev_pp_real")

  list(score = sc_score, money = sc_money)
}

if (sys.nframe() == 0) {
  source(here::here("R", "04_build_panel.R"))
  panel <- build_analysis_panel()
  fits <- run_all(panel)
  saveRDS(fits, file.path(DIR_PROCESSED, "synth_fits.rds"))
  print(synth_inference(fits$score)$table)
}
