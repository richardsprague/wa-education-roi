# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A reproducible synthetic-control study asking whether Washington's post-McCleary
school-finance increase bought measurable NAEP gains. Output is a Quarto website
(`index.qmd` + `notes/methodology.qmd`) built on an R pipeline in `R/`.

**The pipeline has never been executed end to end** (see README "Status"). It was
written against published API docs without R or network access. Assume upstream
field names in `R/01_fetch_naep.R` and `R/02_fetch_finance.R` are the first
things that will break; `require_cols()` in `R/utils.R` is designed to print the
columns actually returned so the fix is mechanical. Do not "fix" a failing pull
by loosening the anchor test — that test is the only guard against the query
silently returning a different subscale.

## Commands

```bash
make docker-build    # pinned rocker/verse:4.4.1 + Posit PPM snapshot image
make docker-run      # full pipeline inside the container
make all             # data + test + render (local R 4.4)
make data            # 01_fetch_naep -> 02_fetch_finance -> 04_build_panel
make data-refresh    # same, bypassing the RDS cache
make test            # anchor validation
make render          # quarto render -> _site/
make clean           # drops _site, .quarto, data/processed, figures; keeps data/raw
```

Each `R/0*.R` script is also runnable standalone (`Rscript R/02_fetch_finance.R`);
the `if (sys.nframe() == 0)` block at the bottom fetches with `refresh = TRUE`
and writes a CSV to `data/processed/`.

Single test file (there is currently one):
`Rscript -e 'testthat::test_file("tests/test_anchors.R", stop_on_failure = TRUE)'`

`make publish` renders then calls `scripts/publish.sh`, which no-ops with a
message unless `PUBLISH_WEB_SH` is exported.

## Architecture

Numbered scripts are a strict dependency chain, each sourcing its predecessors:

- `00_config.R` — **every contestable design decision lives here**: treatment
  unit/year, pre-period start, `EXCLUDE_DONORS` (states with concurrent finance
  shocks), NAEP subscale codes, outcome subject/grade, seed. Changing the
  analysis should almost always mean changing this file, not the estimator.
- `utils.R` — `cache_rds()` (RDS cache under `data/raw/`, keyed by stem),
  `require_cols()`, `require_balanced()`.
- `01`/`02`/`03` — fetchers: NAEP Data Service (undocumented public endpoint),
  Urban Institute Education Data Portal for Census F-33 district finance
  (aggregated to state so numerator and denominator share a district universe),
  CPI-U from FRED + BEA RPP. `03` prefers a manually supplied
  `data/raw/cwift.csv` over RPP if present — CWIFT is the methodologically
  better place-deflator but has no stable API.
- `04_build_panel.R` — joins the three, interpolates annual finance onto
  biennial NAEP years (LOCF, `maxgap = 2`), deflates, enforces balance.
  `donor_states()` applies the exclusions.
- `05_synth.R` — `tidysynth` fit with placebo generation. Two fits: the outcome
  (NAEP score) and the first stage (`rev_pp_real`). Inference is placebo RMSPE
  ranking, deliberately, because five pre-periods make raw gap fit cheap.
- `07_subgroups.R` — reruns outcome + first stage per NAEP subgroup
  (`OUTCOME_GROUP` / `build_analysis_panel(group =)`). Retries a singular
  kernlab fit once with `margin_ipop = 1e-3` and reports that it did.
- `06_plots.R` — `theme_roi()` and `PAL`. Two categorical colors only (treated
  blue, synthetic orange); donors are undifferentiated gray by design.

`index.qmd` sources `04`–`06` in its setup chunk and runs the whole pipeline at
render time, so a broken fetcher breaks the render. Quarto `freeze: auto` caches
chunk results under `.quarto/`.

## Conventions

- No API keys are required for anything in the default path. `BEA_API_KEY` in
  `docker-compose.yml` is optional and unused by the current code.
- Everything under `data/raw`, `data/processed`, `figures`, `_site` is gitignored
  and regenerable. `data/cache/naep_verified_anchors.csv` is the exception: it is
  hand-transcribed from published NCES/OSPI/SBE documents, checked in, and
  trustworthy independently of the pipeline. Only add rows with a `source`
  citation you actually read.
- Prose in `index.qmd` and `notes/methodology.qmd` states numbers inline that
  should agree with what the pipeline computes. If you change the specification,
  check the narrative text too — it is not auto-generated.

## Source articles

Full text of the Seattle Times *Educating Washington* pieces the analysis
responds to lives in `sources/` (gitignored — copyrighted, and this repo is
public; never commit or publish them). Read these instead of re-fetching;
seattletimes.com returns 403 to WebFetch, and Exa's fetch works. Currently:
`superville-2026-09-29-education-spending.md` (installment 2, cited as
`superville2026spending`) and `bazzaz-2026-09-20-paramount-duty.md`
(installment 1, `bazzaz2026paramount`; its chart IDs weren't recoverable, so no CSVs).
Installment 2's four Datawrapper charts are saved beside it as
`st-chart-<id>.csv`, pulled from `datawrapper.dwcdn.net/<id>/<ver>/dataset.csv`:
`77rMl` total real revenue 2012-13..2024-25 (OSPI), `xh7Fk` NCES per-pupil
spending 2010-11..2023-24 (no inflation note, so assume nominal), `64oDu` state
ranking 2023-24 (NCES), `OvD7c` real per-pupil by category 2018-19..2024-25 (OSPI).

**Start here when resuming:** `notes/next-steps.md` — current state of the
uncommitted work and the prioritized research plan.
