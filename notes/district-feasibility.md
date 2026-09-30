# District-level dose-response: feasibility

> **Status:** OPEN — feasibility checked 2026-09-29 for bead `roi-rij`; regionalization factor verified (§4); no outcome estimation yet. Numbers from `scripts/district_feasibility.R`.

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

SEDA 2025.2 (Stanford Educational Opportunity Project, August 2026) publishes
administrative-district means for grades 3–8, math and reading, on a
NAEP-linked scale, for 2008-09 through 2018-19 and 2021-22 through 2024-25.
Subgroups: race, gender, economic disadvantage. Files are public CSVs with a
required citation. The 2024 documentation also required accepting a data use
agreement before download, so check the current terms.

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
  15 miles. The current RCW 28A.150.412 (amended 2018 c 266) reads differently,
  so the 2018 supplemental may have changed factors. **Not yet checked.**
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
3. **Pandemic confound.** If the high-factor metro districts also stayed
   remote longest, which is plausible but **not yet checked**, any 2022+
   outcome confounds the dose with closure length. The COVID-19 School Data
   Hub has district-level 2020-21 learning-mode shares for Washington, so this
   is checkable before relying on post-pandemic years.
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

1. Check whether the 2018 supplemental (2018 c 266 and its budget) changed the
   2018-19 factors, and record which table applied.
2. Download SEDA 2025.2 admin-district annual-by-subject CSV; check WA
   coverage 2015–2019 and the `sedaadmin` ↔ `leaid` match.
3. The narrow 2019 reduced form above, with county or ESD fixed effects to soak
   up some regional trend.
