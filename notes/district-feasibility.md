# District-level dose-response: feasibility

> **Status:** SHIPPED — feasibility (bead `roi-rij`), 2018 factor revision (`roi-hc4`), SEDA 6.0 check (`roi-dhj`) and the narrow 2019 reduced form (`roi-lrb`, §6: null, and underpowered by construction). Numbers from `scripts/district_feasibility.R` and `scripts/district_reduced_form.R`.

The public page ends by saying district data, where the levy cap made the size
of the increase vary, is the way past the state-level power problem. This note
checks whether that is true before building anything.

## Verdict

**The data exist, and so does the variation. The identification is the
problem.** Pre-McCleary levy reliance predicts the *mix* of funding, not the
*amount* (§2). The 2017 regionalization factor does predict the amount (§4),
but it phases in after spring 2018, is assigned by housing values, and runs
straight into the pandemic (§5). A narrow 2019 reduced form is feasible; a
causal district design is not.

## 1. Dose variation (F-33, via the Urban portal already used by `R/02`)

188 districts with 500+ students in both 2011 and 2019, covering 97.6% of 2019
enrollment. Per-pupil growth 2011 → 2019, nominal:

| Measure | p10 | median | p90 |
|---|---|---|---|
| Total revenue per pupil | +37% | +55% | +75% |
| State general formula aid per pupil | +64% | +77% | +96% |
| Current instructional spending per pupil | +34% | +51% | +69% |

That is roughly $4,000 to $7,800 per pupil in total revenue, a wide spread
against a statewide first-stage gap of about $3,065. Enrollment change explains
almost none of it (r = −0.11 with total revenue growth; R² 0.03 with levy share
and size added). Variance is not the constraint.

## 2. The proposed instrument is weak

The idea: the levy swap replaced local levies with state money, so districts
that leaned hardest on levies in 2011 should have seen different net changes.

| Growth measure | Correlation with 2011 local revenue share |
|---|---|
| Formula aid per pupil | +0.44 |
| Instructional spending per pupil | +0.22 |
| Total revenue per pupil | −0.04 |

So the swap is visible in its composition, where levy-reliant districts gained
more state formula money, and it washes out in the total, where they lost
matching local money. As a first stage for *resources*, levy reliance is close
to useless. As a first stage for *instructional spending* it is weak (r = 0.22).
Total revenue is also noisy for a second reason: F-33 `rev_total` includes
capital and bond receipts, which arrive in construction cycles unrelated to
McCleary. Instructional spending is the cleaner dose.

## 3. Outcome data: SEDA

SEDA publishes administrative-district means for grades 3–8, math and
reading, on a NAEP-linked scale, with subgroups by race, gender and economic
disadvantage. It is **two products with separate DOIs**, not one release:

- **SEDA 6.0** (December 2025), 2008-09 through 2018-19:
  edopportunity.org/opportunity/data/, doi 10.25740/xh833nn4025. The 2019
  reduced form needs this one.
- **SEDA 2025.2** (Educational Opportunity Trends Project), 2021-22 through
  2024-25: edopportunity.org/trends/data/, doi 10.25740/np279jm6134.

Download requires entering an email, which accepts the data use agreement and
subscribes you to the newsletter. Archival copies in the Stanford Digital
Repository (purl.stanford.edu/xh833nn4025, /np279jm6134) carry the same terms.
The terms matter for this repo:

- Non-commercial use only.
- "You agree not to publish the data files, in full or in part, without
  explicit permission." The repo and site are public, so raw files stay in
  gitignored `data/raw/seda/`, and no district-level table of SEDA means goes on
  the site. Regression estimates are fine.
- Citation required (Reardon et al., with the DOI above).

Whether the two products share a comparable scale is unverified. 2025.2 is not
downloaded yet.

**SEDA 6.0, checked 2026-09-29 (bead `roi-dhj`).** `scripts/fetch_seda.R` pulls
`seda_admindist_long_cs_6.0.csv` (767 MB; district × subject × grade × year,
cohort-standardized NAEP-linked scale, subgroup columns included), the codebook
and the documentation into `data/raw/seda/`.

- **IDs:** `sedaadmin` is the 7-digit NCES `leaid`. 247 of the 295 factor
  districts match, and the names agree. The 48 unmatched are all tiny districts
  (Washtucna, Benge, Stehekin, Shaw Island, and so on), consistent with
  suppression. The 13 SEDA units without a factor are 8 charters and 5 tribal
  schools.
- **Washington coverage is thin exactly where the trend window needs it.**
  There is no 2014 at all. The documentation (Table 4b) drops a grade × subject
  cell statewide when participation falls under 94%:

  | Year | Grades | Districts (math / reading) |
  |---|---|---|
  | 2009–2013 | 3–8 | about 237 |
  | 2015 | math 4–5; reading 3–5 | 169 / 182 |
  | 2016 | 3–6 | 204 / 208 |
  | 2017 | 3–7 | 215 / 214 |
  | 2018–2019 | 3–8 | 233 / 236 |

- 226 matched districts have 2019 data. 178 have 2019 plus all of 2015–2017 in
  some grade. A comparable-grade trend (grades 4–5) leaves 139 districts for math
  and 145 for reading, about 70–73% of 2019 grade 4–5 test-takers.
- **The missing districts are selected on the treatment.** Seattle and Spokane
  have no 2015–2017 rows in either subject. Tacoma has math only in 2017
  (grades 4–5), and reading in grade 4 or 6 only. Mukilteo, Clover Park and
  Richland also lack grade 4–5 data for 2015–2017. These are high-factor
  districts, so a 2015–2017 trend baseline drops much of the top of the dose
  distribution. Verified for Seattle, Spokane and Tacoma directly in the file.
- **Ways around it:** (a) project from the 2009–2013 trend, which assumes SEDA's
  NAEP linking carries across the 2015 test change; (b) use SEDA's grade-pooled
  district file, whose model estimates through missing cells (not downloaded);
  (c) a 2018 → 2019 change on a half-dose, one-year gap, which is probably too
  small to see.

Open questions for SEDA, not yet checked:

- Washington's coverage by year. Washington changed state tests in 2015
  (MSP to Smarter Balanced). SEDA's NAEP linking is built to absorb that, but
  check the state-subject-year availability table in the documentation.
- The ID crosswalk between SEDA's `sedaadmin` and the CCD `leaid` in F-33.

## 4. The regionalization factor: verified, with strings attached

**What the law says** (EHB 2242, 2017 3rd sp.s. c 13, §§ 101 and 104; read in
the session law and the final bill report):

- From 2018-19, state salary allocations for all three staff categories are
  multiplied by a district regionalization factor. The same act replaced the
  old salary grid, which paid districts for their staff's experience and
  education (the "staff mix"), with statewide average allocations of $64,000
  for teachers, $95,000 for administrators, and $45,912 for classified staff,
  in 2017-18 dollars, adjusted for inflation. The state paid 50% of the
  increase in 2018-19 and 100% in 2019-20.
- The factor is set by formula: districts with median single-family residential
  value above the statewide median (reduced 5%) get +6%, +12%, or +18% by
  tercile. The 2017 text measured value over the district plus districts within
  15 miles. 2018 c 266 (E2SSB 6362) § 203 amended this. See "The 2018 revision"
  below.
- The budget added further adjustments above the formula. These are phased down
  1 or 2 points a year from 2020-21 through 2022-23.
- Hold-harmless: no district may get less salary funding than the prior year
  because of updated regionalization.

**District values.** The enacted 2017 table is LEAP Document 3 of the
Legislative Conference Budget (2017-06-22). It is transcribed to
`data/cache/wa_regionalization_2017.csv` (295 districts, all matched to NCES
`leaid` via the CCD directory). For 2019-20: 202 districts at 1.00, 33 at 1.06,
26 at 1.12, 28 at 1.18, and 6 at 1.24 (the budget add-ons). Shoreline's
1.24 → 1.18 path matches the statute's 2-point phase-down, which cross-checks
the parse.

**The 2018 revision** (2018 c 266 § 203, session law pp. 16–18; LEAP Document
3 re-issued with the 2018 supplemental budget, 2018-03-06, fiscal.wa.gov/leapdocs/2018L3.pdf):

- **Edge adjustment**, new (2)(b): a district west of the Cascade crest that
  borders a district more than one tercile higher gets +6 points, from 2018-19.
  This applies to Washougal, Quilcene and North Mason (1.00 → 1.06) and to
  Concrete, Sedro-Woolley and Mount Baker (1.06 → 1.12), in both staff
  categories.
- **Experience factor**, new (2)(c): +4 points on the *certificated
  instructional* factor only, from 2019-20. It goes to districts whose teachers'
  median experience exceeds the state average and whose ratio of advanced
  degrees to bachelor's degrees is above the state's. That covers 56 districts,
  including Olympia, Walla Walla, Enumclaw and South Whidbey (1.24 → 1.28). The
  table marks them in italics. The italic cells were checked against the PDF's
  font runs, and the set matches exactly the districts where the instructional
  and admin factors differ.
- The rebase cycle shortened from 6 years to 4. The 15-mile rule and the 5%
  median reduction are unchanged.
- The 2019-21 enacted LEAP Doc 3 (dated 2018-12-10) matches the 2018 table for
  all 295 districts. Only two charter schools changed. So **the 2018 table
  governed both 2018-19 and 2019-20**.

That table is `data/cache/wa_regionalization_2018.csv`. It has separate
`rf_cis_*` and `rf_admin_*` columns and flags `experience_adj` and `edge_adj`.
The 2017 CSV is kept as the as-enacted-2017 record. The experience factor is a
problem for the reduced form: it goes to districts with experienced,
credentialed staff, the same trait that §5.5's staff-mix change penalizes, and
possibly a correlate of scores in its own right. It is also post-2019 only, so
for a spring-2019 outcome the dose should be the admin factor or
`rf_cis_2019`, which differ only for the six edge districts. Not checked: the
ESSB 6032 section that incorporates LEAP Doc 3, and the one-time $20M
"regionalization and staff experience safety net" grant for 2018-19.

**First stage (F-33, 2017 → 2020, districts with 500+ students, median $/pupil):**

| Factor | n | State | Local | State + local | Instruction |
|---|---|---|---|---|---|
| 1.00 | 109 | +2,160 | −118 | +2,158 | +1,481 |
| 1.06 | 29 | +2,572 | −102 | +2,396 | +1,599 |
| 1.12 | 21 | +2,863 | +36 | +2,874 | +1,553 |
| 1.18 | 27 | +3,513 | −24 | +3,755 | +2,140 |
| 1.24 | 6 | +3,556 | −180 | +3,264 | +2,005 |

The factor moves real resources. Top-factor districts gained about $1,600 more
per pupil in state-plus-local revenue than 1.00 districts, roughly half the
statewide first-stage gap. Local revenue barely moved in any group through
FY2020, so the 2019 levy cap did not claw it back yet. District-level noise is
large, though: the enrollment-weighted linear fit gives $358 per 6-point step
(t = 4.3, R² 0.09). In percentage terms the gradient looks weaker, because
high-factor districts started from higher bases.

## 5. Why it still may not identify anything

1. **Timing.** The factor starts in 2018-19 at half strength. SEDA's last
   pre-pandemic year is spring 2019, so the only clean post-period is a single
   year of half dose. The next observation is 2022, after the pandemic.
2. **Assignment by housing values.** The factor is a formula, but it is a
   formula in affluence. High-value districts are the Puget Sound suburbs, whose
   score trends and demographic change could differ for reasons unrelated to
   funding. District fixed effects absorb levels, not trends.
3. **Pandemic confound.** ~~Plausible but not yet checked~~ Checked (§7):
   the high-factor metro districts did stay remote longest, with a weighted
   correlation of −0.67 between dose and 2020-21 in-person access. Any 2022+
   outcome confounds the dose with closure length.
4. **Regression discontinuity is thin.** The tercile cutoffs create jumps of 6
   points, but only 93 districts have a factor above 1.00, the budget add-ons
   break sharpness, and the district housing values behind the terciles are not
   in the table. They would have to come from the Department of Revenue.
5. **A second dose moves at the same time.** Dropping the staff-mix grid cut
   relative funding for districts with experienced, credentialed staff, subject
   to the 2018-19 hold-harmless. That is formula-driven too, and would need to
   be modeled alongside regionalization or it contaminates it.

## Verdict, revised

The regionalization factor is real, formula-assigned, public at the district
level, and a working first stage for revenue. As an instrument for scores it is
compromised by timing, since spring 2019 is the only clean post year and it
had half the dose, and by its correlation with region, which the pandemic makes
worse. The most defensible use is narrow: a 2019 reduced form (SEDA spring 2019
minus the district's 2015–2017 trend, regressed on the factor) with the pandemic
years excluded, reported as suggestive. That is a few hours' work once SEDA is
downloaded. A full dose-response design is not worth building on this source.

## Next steps (in order)

1. ~~Check the 2018 supplemental~~ Done: 6 edge districts changed from
   2018-19 and 56 got an experience factor from 2019-20 (§4). The first-stage
   table above uses the 2017 factor and should be re-cut on the 2018 one.
2. ~~Download SEDA 6.0~~ Done (§3). IDs match. The 2015–2017 window is missing
   Seattle, Spokane and most of Tacoma, which forces a choice of trend baseline
   before step 3.
3. ~~The narrow 2019 reduced form~~ Done (§6): null, and too weak to have
   seen the effect the literature predicts.

## 6. The 2019 reduced form (bead `roi-lrb`)

`scripts/district_reduced_form.R`. Outcome: SEDA 6.0 annual-by-subject
district means (pooled over grades, cohort-standardized, so units are national
student SDs). Dose: the 2018-table factor in effect for 2018-19
(`rf_admin_2019`), in 6-point steps. Spring 2018 counts as pre-treatment,
because the factor starts in school year 2018-19. The grade-pooled files do
**not** fill the 2015–2017 hole: the annual pooling needs two or more grades in
the year, so Seattle and Spokane still go from 2013 to 2018. The pre-trend
therefore uses every available year from 2009 to 2018. Sample: districts with
500+ tested students in 2019, which gives 130 for math and 132 for reading, 75
of them with a factor above 1.00. Weighted by test-takers, standard errors
clustered by county (28), county fixed effects unless noted.

| Specification | Math, per step (SE) | Reading, per step (SE) |
|---|---|---|
| 2019 minus own 2009–2018 trend | −0.034 (0.022) | −0.023 (0.016) |
| Same, no county FE | −0.028 (0.007) | −0.020 (0.008) |
| Trend on 2009–2013 + 2018 only | −0.017 (0.014) | −0.006 (0.011) |
| Change 2018 → 2019 | −0.008 (0.007) | −0.008 (0.006) |
| Placebo: 2018 minus 2009–2017 trend | −0.066 (0.037) | −0.039 (0.024) |

**Reading it:**

- **No positive effect in any specification.** Every point estimate is
  negative. With county fixed effects, none are distinguishable from zero.
- **The trend-deviation specs fail their placebo.** High-factor districts were
  already falling below their own trends in 2018, before any dose, and by more
  than in 2019. The significant no-FE estimates are that regional drift (the
  Puget Sound suburbs decelerating relative to their 2009–2013 path), not a
  funding effect. Assignment by housing value (§5.2) shows up just as feared.
- **The year-on-year change is the cleanest spec,** because it differences out
  levels and needs no trend. Its 95% intervals are about [−0.022, +0.006] SD per
  step for math and [−0.020, +0.004] for reading.
- **The design could not have seen the predicted effect.** The first stage is
  about $358 per pupil per step at full dose (FY2020, §4), so roughly half that
  in 2018-19. Jackson & Mackevicius give 0.0316 SD per $1,000 *sustained four
  years*. Even granting four years of exposure, that is about 0.006 SD per step
  at half dose, or 0.011 at full dose. After one year it would be far smaller.
  The upper confidence bounds sit at about the four-year prediction, so the
  interval rules out large effects and says nothing about plausible ones.

**Verdict.** This source cannot tell a benchmark-sized funding effect from zero.
Don't cite §6 as evidence that the money did nothing. It is evidence that a
district-dose design on pre-pandemic SEDA data can't answer the question, which
is what §5 predicted. Also note: 12–16% of 2019 test-takers in the main sample
(Seattle, Spokane and others) have no 2015–2017 data, so their trends rest on
2009–2013 plus 2018.

## 7. Closure length vs dose (bead `roi-5vp`)

`scripts/district_closure_check.R`. Source: the COVID-19 School Data Hub
district shares of the 2020-21 year offered in-person, hybrid and virtual
(OSPI and DSHS monthly data, `DistrictsByShare_Washington_20221015.csv`,
public, in gitignored `data/raw/csdh/`). Access score as in CSDH's own data
series: 100 × in-person share + 50 × hybrid share. All 295 factor districts
match on NCES ID. Weighted by 2020-21 enrollment.

| Dose (6-point steps) | Districts | Students | Access score | Share virtual |
|---|---|---|---|---|
| 0 (factor 1.00) | 199 | 306,654 | 35.3 | 0.41 |
| 1 | 33 | 228,727 | 26.1 | 0.53 |
| 2 | 29 | 131,399 | 20.4 | 0.61 |
| 3 | 28 | 337,662 | 12.2 | 0.76 |
| 4 | 6 | 63,783 | 9.8 | 0.80 |

Access score per dose step: −7.2 (SE 0.5) weighted, −11.7 (1.0) unweighted,
−6.9 (0.5) for districts with 500+ students, and −2.2 (1.2) with county fixed
effects.

**Reading it:** the confound §5.3 feared holds, and it is monotone. Students
in the top-dose districts spent about 80% of 2020-21 in virtual-only
instruction, against 41% in unfactored districts. Most of the gradient is
between counties (Puget Sound vs the rest). Within counties it falls to about
a third and is marginal. County fixed effects would absorb most of it, but they
also absorb most of the dose variation, which is regional by construction.

**Verdict.** Don't fetch SEDA 2025.2 for a 2022+ district dose-response. Any
post-pandemic score gap between high- and low-factor districts runs in the
direction closure length predicts (more remote, lower scores), and it opposes
the funding hypothesis. A null or negative 2022+ estimate would be
uninterpretable. A positive one would be surprising, but no one should build a
design on the hope of that result.
