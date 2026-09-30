## district_reduced_form.R -- did districts with a higher 2018 regionalization
## factor gain more in spring 2019 than their own pre-trend predicted?
## Bead roi-lrb; see notes/district-feasibility.md section 6.
##
## Timing: the factor applies from school year 2018-19 at half strength, so
## spring 2019 is the only treated year before the pandemic and spring 2018 is
## still pre. SEDA 6.0 has no Washington 2014, and drops Seattle and Spokane
## entirely for 2015-2017, so the pre-trend uses every available year
## 2009-2018 rather than a fixed window.
##
## SEDA terms forbid republishing the data in full or in part: this script
## prints regression estimates only and writes nothing district-level.
## Requires scripts/fetch_seda.R plus seda_admindist_annualsub_cs_6.0.csv.

source(here::here("R", "00_config.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(data.table)
})

SEDA     <- here::here("data", "raw", "seda", "seda_admindist_annualsub_cs_6.0.csv")
RF       <- here::here("data", "cache", "wa_regionalization_2018.csv")
MIN_ASMT <- 500   # grade-pooled test-takers in 2019, per subject

seda <- fread(SEDA)[stateabb == "WA" & subgroup == "all" & gap == 0]

long <- rbind(
  seda[, .(leaid = sedaadmin, year, subject = "math",
           y = cs_mn_avg_mth_ol, se = cs_mn_avg_mth_ol_se, n = tot_asmts_mth)],
  seda[, .(leaid = sedaadmin, year, subject = "reading",
           y = cs_mn_avg_rla_ol, se = cs_mn_avg_rla_ol_se, n = tot_asmts_rla)]
)[!is.na(y)]

rf <- read.csv(RF, colClasses = c(ospi_code = "character")) |>
  transmute(leaid, county = substr(ospi_code, 1, 2),
            dose = (rf_admin_2019 - 1) / 0.06,   # in 6-point steps
            experience_adj, edge_adj)

## One row per district x subject: 2019 score, its deviation from a linear
## trend fit on pre years, and the plain 2018 -> 2019 change.
deviations <- function(pre_years) {
  long[, {
    pre <- .SD[year %in% pre_years]
    y19 <- y[year == 2019]; y18 <- y[year == 2018]
    ok  <- length(y19) == 1 && nrow(pre) >= 3 && any(pre$year >= 2013)
    if (!ok) NULL else {
      fit <- lm(y ~ I(year - 2019), data = pre)
      .(dev = y19 - coef(fit)[[1]],
        chg = if (length(y18) == 1) y19 - y18 else NA_real_,
        n19 = n[year == 2019], n_pre = nrow(pre),
        has_1517 = any(pre$year %in% 2015:2017))
    }
  }, by = .(leaid, subject)] |>
    as_tibble() |>
    inner_join(rf, by = "leaid") |>
    filter(n19 >= MIN_ASMT)
}

## County-clustered sandwich SE, CR1 small-sample correction.
cluster_se <- function(fit, cl) {
  X <- model.matrix(fit); e <- resid(fit); w <- weights(fit)
  if (is.null(w)) w <- rep(1, length(e))
  bread <- solve(crossprod(X * sqrt(w)))
  S <- rowsum(X * w * e, cl)
  G <- nrow(S); N <- nrow(X); K <- ncol(X)
  V <- bread %*% crossprod(S) %*% bread * (G / (G - 1)) * ((N - 1) / (N - K))
  sqrt(diag(V))
}

est <- function(d, outcome, fe = TRUE) {
  d <- d[is.finite(d[[outcome]]), ]
  f <- if (fe) reformulate(c("dose", "factor(county)"), outcome)
       else    reformulate("dose", outcome)
  fit <- lm(f, data = d, weights = n19)
  b <- coef(fit)[["dose"]]; s <- cluster_se(fit, d$county)[["dose"]]
  tibble(n = nrow(d), treated = sum(d$dose > 0), counties = n_distinct(d$county),
         b = b, se = s, t = b / s)
}

specs <- list(
  "trend 2009-2018, county FE"    = list(pre = c(2009:2013, 2015:2018), y = "dev", fe = TRUE),
  "trend 2009-2018, no FE"        = list(pre = c(2009:2013, 2015:2018), y = "dev", fe = FALSE),
  "trend 2009-2013 + 2018"        = list(pre = c(2009:2013, 2018),      y = "dev", fe = TRUE),
  "change 2018 -> 2019"           = list(pre = c(2009:2013, 2015:2018), y = "chg", fe = TRUE),
  "placebo: 2018 dev, trend to 2017" = list(pre = NULL, y = NULL, fe = TRUE)
)

## Placebo: pretend 2018 was treated. Same machinery, shifted one year.
placebo <- function() {
  long18 <- long[year <= 2018]
  long18[, {
    pre <- .SD[year <= 2017]; y18 <- y[year == 2018]
    ok  <- length(y18) == 1 && nrow(pre) >= 3 && any(pre$year >= 2013)
    if (!ok) NULL else {
      fit <- lm(y ~ I(year - 2018), data = pre)
      .(dev = y18 - coef(fit)[[1]], n19 = n[year == 2018])
    }
  }, by = .(leaid, subject)] |>
    as_tibble() |> inner_join(rf, by = "leaid") |> filter(n19 >= MIN_ASMT)
}

res <- purrr::imap_dfr(specs, function(s, nm) {
  purrr::map_dfr(c("math", "reading"), function(subj) {
    d <- if (is.null(s$pre)) placebo() else deviations(s$pre)
    est(filter(d, subject == subj), s$y %||% "dev", s$fe) |>
      mutate(spec = nm, subject = subj, .before = 1)
  })
})

cli::cli_h2("Spring 2019 on regionalization dose (per 6-point step), cs SD units")
print(res |> mutate(across(c(b, se), \(x) round(x, 4)), t = round(t, 2)),
      n = Inf, width = Inf)

## Coverage of the main sample: who lacks 2015-2017 and relies on 2009-13 + 2018.
main <- deviations(c(2009:2013, 2015:2018))
cli::cli_h2("Main sample coverage")
print(main |> group_by(subject, dose_gt0 = dose > 0) |>
        summarise(districts = n(), no_1517 = sum(!has_1517),
                  asmt_2019 = sum(n19), .groups = "drop"))

## Scale for the write-up: SD of district deviations, and the enrollment
## share of districts lacking any 2015-2017 year.
cli::cli_h2("Scale")
print(main |> group_by(subject) |>
        summarise(sd_dev = round(sd(dev), 4),
                  share_asmt_no_1517 = round(sum(n19[!has_1517]) / sum(n19), 3)))
