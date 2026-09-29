## 07_subgroups.R -- the synthetic control rerun on NAEP subgroup means.
##
## Question: did the McCleary money move scores for the students it was most
## argued to help? (Roza, Reykdal, Braun in Seattle Times installment 2.)
##
## Caveats that travel with every number here:
##   - The first stage is still state-level revenue per pupil, so this asks
##     "did the state's increase move this group," not targeted-dollar exposure.
##     It is refit on each subgroup's own donor pool so the pair is consistent.
##   - Small states suppress subgroup cells; require_balanced() drops any state
##     missing a year, so the donor pool shrinks (Hispanic: 25 vs 39).
##   - SLUNCH3 "Eligible" changes meaning mid-window: Community Eligibility
##     Provision adoption from 2014-15 alters who is classified eligible.
##   - The J&M benchmark applies the pooled 0.0316 SD / $1,000 and the all-
##     student NAEP SD; the meta-analysis finds larger effects for low-income
##     students, so the prediction is, if anything, low.

source(here::here("R", "04_build_panel.R"))
source(here::here("R", "05_synth.R"))

SUBGROUPS <- list(
  all      = c(variable = "TOTAL",   value = "1"),
  hispanic = c(variable = "SDRACE",  value = "3"),
  nslp     = c(variable = "SLUNCH3", value = "1")
)

JM_SD_PER_1000 <- 0.0316
## Student-level SD, national public, 2019, NAEP Data Service stattype SD:SD.
NAEP_SD_2019   <- c(mathematics_8 = 39.82, reading_4 = 38.77)

#' fit_synth(), retried once with a looser ipop margin if the solver goes
#' singular. On the NSLP panel the default tolerances fail and every nearby
#' setting (margin 1e-4 or 1e-3, sigf 4 or 6, bound 5) succeeds, so this is
#' numerical bad luck rather than a degenerate donor pool. Records which ran.
fit_synth_retry <- function(panel, outcome_col, donors = NULL) {
  fit <- tryCatch(fit_synth(panel, outcome_col, donors = donors), error = function(e) {
    if (!grepl("singular", conditionMessage(e))) stop(e)
    cli::cli_warn("{outcome_col}: singular at default ipop tolerances; retrying margin_ipop = 1e-3.")
    NULL
  })
  if (!is.null(fit)) return(list(fit = fit, retried = FALSE))
  list(fit = fit_synth(panel, outcome_col, donors = donors, margin_ipop = 1e-3),
       retried = TRUE)
}

#' Fit outcome + first stage for one group and summarise.
#'
#' @param exclude extra donors to drop for this run only (e.g. "MS" for grade 4
#'   reading, where its 2013 Literacy-Based Promotion Act is a concurrent
#'   reading treatment).
run_subgroup <- function(group, refresh = FALSE, subject = OUTCOME_SUBJECT,
                         grade = OUTCOME_GRADE, exclude = character(0)) {
  panel <- build_analysis_panel(refresh = refresh, group = group,
                                subject = subject, grade = grade)
  donors <- setdiff(donor_states(panel), exclude)
  naep_sd <- NAEP_SD_2019[[paste0(subject, "_", grade)]]
  score_fit <- fit_synth_retry(panel, "score", donors)
  score <- score_fit$fit
  ## First stage in $thousands: on the 25-state Hispanic pool the dollar-scale
  ## fit makes kernlab's solver singular; the rescaled fit does not. Gaps are
  ## scaled back below, and the `all` row is a check against the main page.
  money_panel <- panel |>
    dplyr::filter(!is.na(rev_pp_real)) |>
    dplyr::mutate(rev_pp_real_k = rev_pp_real / 1000)
  money_fit <- fit_synth_retry(money_panel, "rev_pp_real_k", donors)
  money <- money_fit$fit

  post <- function(sc) {
    synth_effects(sc) |>
      dplyr::filter(time_unit >= TREAT_YEAR, time_unit <= 2019) |>
      dplyr::select(time_unit, gap) |>
      tibble::deframe()
  }
  score_gap <- post(score)
  money_gap <- post(money) * 1000

  placebo_abs <- score |>
    tidysynth::grab_synthetic_control(placebo = TRUE) |>
    dplyr::mutate(gap = real_y - synth_y) |>
    dplyr::filter(time_unit >= TREAT_YEAR, .id != TREAT_UNIT) |>
    dplyr::group_by(.id) |>
    dplyr::summarise(m = mean(abs(gap)), .groups = "drop") |>
    dplyr::pull(m)

  pre_rmspe <- synth_effects(score) |>
    dplyr::filter(time_unit < TREAT_YEAR) |>
    dplyr::summarise(r = sqrt(mean(gap^2))) |>
    dplyr::pull(r)

  inf <- synth_inference(score)
  w <- tidysynth::grab_unit_weights(score) |> dplyr::arrange(dplyr::desc(weight))
  tibble::tibble(
    subject       = subject,
    grade         = as.integer(grade),
    group         = paste0(group[["variable"]], ":", group[["value"]]),
    n_donors      = length(donors),
    pre_rmspe     = pre_rmspe,
    gap_2013      = score_gap[["2013"]],
    gap_2015      = score_gap[["2015"]],
    gap_2017      = score_gap[["2017"]],
    gap_2019      = score_gap[["2019"]],
    rank          = inf$rank,
    n_units       = nrow(inf$table),
    p_value       = inf$p_value,
    detect_floor  = unname(stats::quantile(placebo_abs, 0.95)),
    money_2019    = money_gap[["2019"]],
    jm_pred_2019  = money_gap[["2019"]] / 1000 * JM_SD_PER_1000 * naep_sd,
    top_donor     = w$unit[1],
    top_weight    = w$weight[1],
    ms_weight     = sum(w$weight[w$unit == "MS"]),
    retried       = score_fit$retried || money_fit$retried
  )
}

run_subgroups <- function(groups = SUBGROUPS, refresh = FALSE) {
  purrr::map_dfr(groups, run_subgroup, refresh = refresh, .id = "label")
}

#' Grade 4 reading, all students, with and without Mississippi. Answers the
#' Mississippi comparison (Aramaki, Seattle Times installment 2): its reading
#' gains are a grade 4 story, so the grade 8 math fit cannot speak to them.
run_reading4 <- function(refresh = FALSE) {
  all <- c(variable = "TOTAL", value = "1")
  dplyr::bind_rows(
    with_ms    = run_subgroup(all, refresh, "reading", 4L),
    without_ms = run_subgroup(all, refresh, "reading", 4L, exclude = "MS"),
    .id = "label"
  )
}

if (sys.nframe() == 0) {
  res <- dplyr::bind_rows(run_subgroups(), run_reading4())
  readr::write_csv(res, file.path(DIR_PROCESSED, "subgroup_results.csv"))
  print(res, width = Inf)
}
