## district_closure_check.R -- did districts with a higher regionalization
## factor also stay remote longer in 2020-21? If so, any 2022+ district
## outcome confounds the funding dose with closure length.
## Bead roi-5vp; see notes/district-feasibility.md section 5.3.
##
## Source: COVID-19 School Data Hub, "DistrictsByShare_Washington_20221015.csv"
## (share of 2020-21 school year each district offered in-person, hybrid,
## virtual; OSPI + DSHS monthly data). Public, no use agreement. Download:
##   https://www.covidschooldatahub.com/states/washington
## into data/raw/csdh/. Enrollment weights come from the district file
## "Washington_Districts_LearningModelData_Final.csv" on the same page.
##
## Access score follows CSDH's own data series: 100 * in-person + 50 * hybrid.

source(here::here("R", "00_config.R"))

suppressPackageStartupMessages(library(dplyr))

CSDH <- here::here("data", "raw", "csdh")
RF   <- here::here("data", "cache", "wa_regionalization_2018.csv")

share <- read.csv(file.path(CSDH, "DistrictsByShare_Washington_20221015.csv")) |>
  transmute(leaid = NCESDistrictID,
            access = 100 * share_inperson + 50 * share_hybrid,
            share_virtual)

enrol <- read.csv(file.path(CSDH, "Washington_Districts_LearningModelData_Final.csv"),
                  fileEncoding = "UTF-8-BOM") |>
  distinct(leaid = NCESDistrictID, enrol = EnrollmentTotal)

rf <- read.csv(RF, colClasses = c(ospi_code = "character")) |>
  transmute(leaid, county = substr(ospi_code, 1, 2),
            dose = (rf_admin_2019 - 1) / 0.06)   # in 6-point steps

d <- inner_join(rf, share, by = "leaid") |> inner_join(enrol, by = "leaid")
cat(sprintf("Matched %d of %d factor districts (%d with factor > 1.00)\n",
            nrow(d), nrow(rf), sum(d$dose > 0)))

cat("\nEnrollment-weighted 2020-21 access score and virtual share, by dose step\n")
d |>
  group_by(dose = round(dose)) |>
  summarise(districts = n(), students = sum(enrol),
            access = weighted.mean(access, enrol),
            virtual = weighted.mean(share_virtual, enrol), .groups = "drop") |>
  mutate(across(c(access, virtual), \(x) round(x, 2))) |>
  print()

cat("\nAccess score on dose (per 6-point step), weighted by enrollment\n")
fits <- list(
  "all districts"        = lm(access ~ dose, d, weights = enrol),
  "all, county FE"       = lm(access ~ dose + factor(county), d, weights = enrol),
  "500+ students"        = lm(access ~ dose, filter(d, enrol >= 500), weights = enrol),
  "unweighted"           = lm(access ~ dose, d)
)
for (nm in names(fits)) {
  s <- summary(fits[[nm]])$coefficients["dose", ]
  cat(sprintf("  %-16s %6.2f (%.2f)\n", nm, s[1], s[2]))
}
cat(sprintf("\nWeighted correlation, dose vs access: %.2f\n",
            cov.wt(d[, c("dose", "access")], wt = d$enrol, cor = TRUE)$cor[1, 2]))
