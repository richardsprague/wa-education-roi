# District-level dose-response: feasibility

> **Status:** OPEN — feasibility checked 2026-09-29 for bead `roi-rij`; no estimation yet. Numbers from `scripts/district_feasibility.R`.

The public page ends by saying district data, where the levy cap made the size
of the increase vary, is the way past the state-level power problem. This note
checks whether that is true before building anything.

## Verdict

**The data exist, and so does the variation. The identification is the
problem.** Washington's districts got very different increases, but the obvious
formula-driven source of that difference, pre-McCleary levy reliance, predicts
the *mix* of funding and not the *amount*. Without an exogenous source of dose,
a within-state dose-response regression compares districts that got more money
for reasons that probably also move scores.

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

## 4. What would make it work

A source of dose variation set by formula rather than by district choice. The
candidate worth verifying is the **regionalization factor** in the 2017
McCleary legislation, which scaled state salary allocations by district,
reportedly based on local housing values. If that holds, it is a
formula-assigned dose that districts did not choose. **Not verified.** Read
the statute or OSPI's apportionment documentation before relying on it.
Hold-harmless provisions would also need mapping.

Failing that, the fallback is descriptive: a district event study of SEDA
scores against the instructional-spending change, reported as a correlation
with the confounding stated plainly. It is still more informative than the
state mean, but it is not causal.

## Next steps (in order)

1. Verify the regionalization factor: source, formula, district-level values.
2. Download SEDA 2025.2 admin-district annual-by-subject CSV; check WA coverage
   2009–2019 and the `leaid` crosswalk.
3. If (1) holds: dose-response of instructional spending per pupil on the
   regionalization factor, then reduced form on SEDA scores.
