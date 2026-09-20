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
    )

  ## NOTE: resources are deliberately NOT matching predictors.
  ##
  ## With five pre-treatment periods the predictor matrix can identify at
  ## most five predictors; adding rev_pp_pre_mean and state_share_pre_mean on
  ## top of five outcome lags makes kernlab's interior-point solver singular
  ## (verified 2026-09-20: 7 predictors fails, 5 succeeds, and rescaling the
  ## dollar variables does not help -- it is the count, not the units).
  ##
  ## This is also the canonical Abadie specification. Real cost-adjusted
  ## revenue is the *treatment mechanism*, estimated separately as the first
  ## stage in run_all(), not a covariate the donor pool must match on.

  ## Individual pre-period outcome lags, which is what actually drives fit.
  ##
  ## Deliberately NOT accompanied by a pre-period mean of the outcome: the mean
  ## is an exact linear combination of these lags, and including both makes the
  ## predictor matrix singular ("system is computationally singular" out of
  ## solve() inside the optimizer).
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

  ## First stage. F-33 coverage stops at 2020 and align_finance_to_naep()
  ## cannot carry it as far as NAEP 2022/2024 (the NA run is longer than its
  ## maxgap), so rev_pp_real is missing in those two years for every state.
  ## Restrict this fit to the years where the outcome is actually observed
  ## rather than handing NAs to the optimizer; the panel stays balanced
  ## because the missingness is all-or-nothing by year.
  money_panel <- dplyr::filter(panel, !is.na(rev_pp_real))
  money_years <- sort(unique(money_panel$year))
  cli::cli_h2("First stage: real cost-adjusted revenue per pupil")
  cli::cli_alert_info(
    "Restricted to {min(money_years)}-{max(money_years)} (finance coverage)."
  )
  sc_money <- fit_synth(money_panel, "rev_pp_real")

  list(score = sc_score, money = sc_money)
}

if (sys.nframe() == 0) {
  source(here::here("R", "04_build_panel.R"))
  panel <- build_analysis_panel()
  fits <- run_all(panel)
  saveRDS(fits, file.path(DIR_PROCESSED, "synth_fits.rds"))
  print(synth_inference(fits$score)$table)
}
