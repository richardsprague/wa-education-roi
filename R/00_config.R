## 00_config.R -- paths, constants, and the analysis design decisions.
## Everything a reviewer would want to argue with should be visible in this file.

suppressPackageStartupMessages({
  library(here)
})

DIR_RAW       <- here::here("data", "raw")
DIR_CACHE     <- here::here("data", "cache")
DIR_PROCESSED <- here::here("data", "processed")
DIR_FIGURES   <- here::here("figures")

for (d in c(DIR_RAW, DIR_CACHE, DIR_PROCESSED, DIR_FIGURES)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

## ---- Treatment definition -------------------------------------------------
## McCleary v. State was decided Jan 2012. The legislature's response phased in
## over 2013-2019, with the largest salary increases landing in SY 2018-19.
## We date treatment onset to the first NAEP administration after the ruling.
TREAT_UNIT <- "WA"
TREAT_YEAR <- 2013L

## ---- Pre-period -----------------------------------------------------------
## State-level NAEP became universal with NCLB (2003). Using 2003+ keeps the
## panel balanced across all 50 states at the cost of only five pre-treatment
## observations (2003, 2005, 2007, 2009, 2011). That is thin: the synthetic
## control fit will be easy to achieve and correspondingly easy to overfit,
## which is exactly why placebo-based inference (not the gap alone) is the
## headline result. Set PRE_START <- 1996 to trade balance for more pre-periods.
PRE_START <- 2003L
NAEP_YEARS <- c(2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2022, 2024)

## ---- Donor pool exclusions ------------------------------------------------
## SUTVA requires donors untreated by comparable school-finance shocks during
## the study window. These states saw major court-ordered or legislated finance
## overhauls, or statewide funding-formula rewrites, between 2008 and 2022.
## This list is a judgment call and the single most contestable input here --
## rerun with EXCLUDE_DONORS <- character(0) to see how much it matters.
EXCLUDE_DONORS <- c(
  "KS",  # Gannon v. State, ongoing orders 2014-2019
  "NY",  # Campaign for Fiscal Equity settlement / Foundation Aid phase-in
  "NJ",  # Abbott successor litigation, SFRA full funding
  "CT",  # CCJEF v. Rell, 2016 ruling
  "PA",  # William Penn SD v. Dept. of Education, formula overhaul
  "NM",  # Yazzie/Martinez v. State, 2018
  "TX",  # HB 3 (2019) formula rewrite
  "CA",  # Local Control Funding Formula (2013) -- large, progressive, concurrent
  "MI",  # Multiple emergency-management/funding shocks
  "IL"   # Evidence-Based Funding Formula (2017)
)

## Non-state NAEP jurisdictions to drop from the donor pool.
NON_STATES <- c("DC", "DD", "AS", "GU", "PR", "VI", "NT", "NP", "NL")

## ---- Outcome specification ------------------------------------------------
## NAEP subscale codes used by the NAEP Data Service.
NAEP_SUBSCALE <- c(mathematics = "MRPCM", reading = "RRPCM")

## Primary outcome. Grade 8 math has the longest clean state series and is the
## least sensitive to early-grade compositional churn.
OUTCOME_SUBJECT <- "mathematics"
OUTCOME_GRADE   <- 8L

## ---- Reproducibility ------------------------------------------------------
SEED <- 20260920L
set.seed(SEED)
