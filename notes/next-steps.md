# Next steps

> **Status:** SUPERSEDED — 2026-09-29, items moved to beads (`bd list`, prefix `roi-`, stealth mode so `.beads/` stays out of the public repo). Kept for the reasoning behind each item.

## Where things stand (2026-09-29)

- **Committed 2026-09-29:** everything since `e02fde5` — the 09-22/23 rewrite (`R/06_plots.R`, `index.qmd`, `references.bib`) plus the 09-29 edits below, `.gitignore` (`sources/`), and the `CLAUDE.md` "Source articles" section. Richard commits; don't.
- **09-29 edits to `index.qmd`:**
  - Opening section now engages Superville's installment 2 (`superville2026spending`; full text in `sources/`, gitignored).
  - "How large an effect could have hidden?" adds the Jackson & Mackevicius (2024) benchmark (`jackson2024expect`): 0.0316 SD per $1,000/pupil sustained 4 years. Constants `JM_SD_PER_1000` and `NAEP_SD` (national public, grade 8 math student SD: 36.42 in 2013, 39.82 in 2019, from NAEP Data Service `stattype=SD:SD`) sit in the `bound` chunk. Renders as a **3.5–3.9 point** predicted effect against the **5.5 point** detection floor.
  - Verdict headline changed from "No" to "Not detectably". Closing paragraph points at subgroups.
- **Verified first-stage gap by year** (WA minus synthetic, real cost-adjusted $/pupil): 2011 $18 · 2013 $447 · 2015 $1,381 · 2017 $1,800 · 2019 $3,065. Cited in the text as evidence the 2019 cohort had far less than 4 years of full exposure.
- `make render` passes; no unresolved citations.
- **Follow-up edits (same day, committed):** fuller Pedersen quote; opening cites the NCES 18th-in-spending rank, the Stanford recovery rank, and Mississippi; `money_gap` (per-year first-stage vector, `money_2019` kept) and `score_gaps_2019` now feed the inline numbers that were hardcoded. Render verified: values unchanged.

## Recommended next steps, in priority order

### 1. Subgroup synthetic control (the main one)

The strongest open objection — made by Roza, Reykdal, and Braun in installment 2, and in the draft's own "cannot settle" section — is that the money didn't reach, or wasn't measured on, the students it matters most for. The meta-analysis benchmark also says effects are larger for disadvantaged students. A state mean can't test that. NAEP subgroup means can.

- Verified working NAEP Data Service variables (grade 8 math, WA, 2019):
  - `SDRACE` → White 291.8, Black 258.7, Hispanic 267.4, Asian/PI 305.9, AI/AN 259.3, Two+ 291.8
  - `SLUNCH3` → Eligible 268.3, Not eligible 302.3, "Information not available" = 999 (suppression sentinel — filter it)
- Plan: parameterize `R/01_fetch_naep.R` by variable/value, add an outcome-group setting to `R/00_config.R`, run `05_synth.R` per group. Start with `SLUNCH3 = Eligible` (closest to "high-poverty") and Hispanic (largest WA minority group).
- Watch for: suppressed cells in small donor states (the panel must stay balanced; `require_balanced()` will catch it). Donors may need restricting to states that report the group every year. The anchor test covers only the all-students series — add subgroup anchors from published NCES tables before trusting the pull (per `CLAUDE.md`, only rows with a source actually read).
- Caveat: the first stage (`rev_pp_real`) is state-level, so the subgroup analysis is still "did the state's increase move this group," not targeted-dollar exposure.

### 2. Extend the revenue series past 2020

F-33 ends at 2020. Installment 2 cites OSPI: $13.4B (2012-13) → $21B+ (2024-25), inflation-adjusted, **total, not per pupil**, CPI-only. To use it: OSPI F-196 revenue ÷ OSPI enrollment, then apply the pipeline's own CPI + RPP deflation. Useful for the narrative (did the gap keep widening?); it won't feed the synth, because donors need the same source.

### 3. Deflator question worth a paragraph in `notes/methodology.qmd`

The treatment was largely teacher salaries (NEA 2026: WA avg $96,589, 3rd nationally; installment 2). If the place deflator moves up with Puget Sound wages, it partly deflates away the treatment. RPP is a general price index, so this is modest; CWIFT (preferred per `R/03`) is a comparable-*wage* index for non-teachers, so the same logic applies more strongly. Check how much the $3,065 first-stage gap changes under CPI-only as a bound.

### 4. Smaller items

- **Save installment 1** (Bazzaz, 2026-09-20, `bazzaz2026paramount`) to `sources/` the same way (Exa fetch; seattletimes.com 403s WebFetch).
- **Mississippi** (Bellevue's Aramaki in installment 2): a grade 4 *reading* story. The current outcome is grade 8 math, so the draft can't speak to it. Either say so in "What this can and cannot settle", or do a grade 4 reading run (`OUTCOME_SUBJECT`, `OUTCOME_GRADE` in `00_config.R`). Mississippi's weight in the donor pool is worth checking either way.
- **Pandemic closure length** (Pedersen: WA closed longer than most). Only affects 2022/2024, which the draft already sets aside; one sentence citing a closure-duration source would pre-empt the objection.
- **Stanford Educational Opportunity Project** (May 2026): WA 27th/38 math, 23rd/35 reading in pandemic recovery. Could be cited alongside the 2022/2024 caveat; not yet in `references.bib`.
- **Installment 3** of *Educating Washington* is "What's the purpose of education?" Relevant to the draft's "paramount duty" framing; save to `sources/` when it runs.
