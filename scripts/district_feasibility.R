## district_feasibility.R -- how much did the McCleary increase vary across
## Washington districts, and does pre-McCleary levy reliance predict it?
## Feasibility check for bead roi-rij; see notes/district-feasibility.md.
##
## Nominal dollars throughout: within one state and one pair of years the
## deflator is a common factor, so it cannot change rankings or correlations.

source(here::here("R", "00_config.R"))
source(here::here("R", "utils.R"))

suppressPackageStartupMessages(library(dplyr))

YEARS   <- c(2011, 2017, 2019)
MIN_ENR <- 500   # drop tiny districts, whose per-pupil figures are noise

wa_raw <- cache_rds(
  key = "ccd_finance_wa_districts",
  expr = purrr::map_dfr(YEARS, function(y) {
    educationdata::get_education_data(
      level = "school-districts", source = "ccd", topic = "finance",
      filters = list(year = y, fips = 53)
    ) |> mutate(across(everything(), as.character))
  })
)

num <- function(x) { x <- as.numeric(x); if_else(x < 0, NA_real_, x) }

d <- wa_raw |>
  transmute(
    year = as.integer(year), leaid,
    enr  = num(enrollment_fall_responsible),
    rev  = num(rev_total),
    loc  = num(rev_local_total),
    form = num(rev_state_gen_formula_assist),
    inst = num(exp_current_instruction_total)
  ) |>
  filter(enr > 0) |>
  mutate(rev_pp = rev / enr, form_pp = form / enr, inst_pp = inst / enr,
         loc_share = loc / rev)

w <- d |>
  tidyr::pivot_wider(id_cols = leaid, names_from = year,
                     values_from = c(enr, rev_pp, form_pp, inst_pp, loc_share)) |>
  filter(enr_2011 >= MIN_ENR, enr_2019 >= MIN_ENR) |>
  mutate(
    g_rev  = rev_pp_2019  / rev_pp_2011  - 1,
    g_form = form_pp_2019 / form_pp_2011 - 1,
    g_inst = inst_pp_2019 / inst_pp_2011 - 1,
    g_enr  = enr_2019     / enr_2011     - 1
  ) |>
  filter(if_all(c(g_rev, g_form, g_inst), is.finite))

q <- function(x) round(stats::quantile(x, c(.1, .5, .9)), 2)
r <- function(a, b) round(stats::cor(a, b, use = "complete.obs"), 2)

cli::cli_h2("Washington districts with {MIN_ENR}+ students, 2011 -> 2019")
cat("districts:", nrow(w), "\n")
cat("share of 2019 enrollment:",
    round(sum(w$enr_2019) / sum(d$enr[d$year == 2019]), 3), "\n")
cat("growth p10/p50/p90  total revenue pp:", q(w$g_rev), "\n")
cat("                    formula aid pp:  ", q(w$g_form), "\n")
cat("                    instruction pp:  ", q(w$g_inst), "\n")
cat("cor with 2011 local revenue share -- total:", r(w$loc_share_2011, w$g_rev),
    " formula:", r(w$loc_share_2011, w$g_form),
    " instruction:", r(w$loc_share_2011, w$g_inst), "\n")
cat("cor(enrollment growth, total revenue pp growth):", r(w$g_enr, w$g_rev), "\n")
