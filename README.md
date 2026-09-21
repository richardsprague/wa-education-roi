# wa-education-roi

Did Washington's McCleary school-finance response buy measurable achievement?

A reproducible synthetic-control study. Public data, scripted pulls, pinned
container, Quarto output.

**Read it here: <https://richardsprague.com/docs/policy/education/>**
([methodology](https://richardsprague.com/docs/policy/education/notes/methodology.html))

## The claim under test

Washington's state K–12 spending rose 110% from the 2009–11 to the 2019–21
biennium while the state's NAEP standing relative to the nation did not improve.
That juxtaposition is suggestive but not an estimate. This repo turns it into
one, after correcting the resource measure for three things the headline number
ignores: the levy swap, inflation, and regional cost of labor.

## Quick start

```bash
make docker-build    # build the pinned R 4.4 + Quarto image
make all             # fetch data, validate against published figures, render
open _site/index.html
```

> **On Apple Silicon, `make docker-build` fails** — the base image is amd64
> only. Use the local route below, or see Reproducibility.

Without Docker, on a local R 4.4 or later install:

```bash
Rscript -e 'install.packages(readLines("dependencies.txt"))'
make data test render
```

## Layout

```
R/00_config.R        every contestable design decision, in one file
R/01_fetch_naep.R    NAEP Data Service (NCES) state scale scores
R/02_fetch_finance.R Census F-33 / CCD via Urban Institute API
R/03_price_adjust.R  CPI-U and BEA RPP deflators; CWIFT if supplied
R/04_build_panel.R   join, align finance to NAEP years, balance the panel
R/05_synth.R         tidysynth estimation + placebo inference
R/06_plots.R         chart theme and figures
tests/test_anchors.R API output vs hand-verified published figures
index.qmd            the analysis
notes/methodology.qmd specification checks and threats to validity
```

## Data provenance

| Source | What | Key required |
|---|---|---|
| [NAEP Data Service](https://www.nationsreportcard.gov/) | State mean scale scores | No |
| [Urban Institute Education Data Portal](https://educationdata.urban.org/) | Census F-33 district finance | No |
| [BEA Regional Price Parities](https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area) | State cost-of-living index | No |
| FRED `CPIAUCSL` | CPI-U | No |
| [NCES CWIFT](https://nces.ed.gov/programs/edge/economic/) | Teacher comparable wage index | Manual download |

Raw pulls are cached to `data/raw/` as RDS and gitignored; re-fetch with
`make data-refresh`.

## Validation

`make test` re-fetches a handful of NAEP figures and asserts they match numbers
transcribed by hand from published NCES/OSPI/SBE documents
(`data/cache/naep_verified_anchors.csv`). If NCES changes the Data Service
schema or the query silently starts returning a different subscale, the build
fails rather than producing a plausible-looking wrong answer.

## Status

**Executed end to end on 2026-09-20** (R 4.6.1, arm64 macOS, outside the pinned
container — see Reproducibility below). `make test` passes 10/10, `make render`
builds the site. The first run turned up seven defects, all of them schema drift
or numerical conditioning rather than analysis logic:

- The NAEP response carries its own `subject` column coded `"MAT"`, which masked
  the function argument inside `transmute()`, so the anchor join matched nothing.
- Urban's finance field is `exp_current_instruction_total`.
- The portal intermittently 404s a page under load; the multi-year pull is now
  cached per year and retried.
- F-33 coverage ends at 2020, not 2022.
- FRED gates `fredgraph.csv` on User-Agent — it serves curl's default but hangs
  on any custom one, which is why R failed where the `curl` binary worked.
- The BEA zip member is `SARPP_STATE_2008_2024.csv`, not `SARPP1`.
- The predictor set was unidentifiable: a pre-period outcome mean is an exact
  linear combination of the outcome lags, and seven predictors against five
  pre-treatment periods is singular regardless of scaling.

The verified figures in `data/cache/naep_verified_anchors.csv` are confirmed
against published sources and can be trusted independently of the pipeline. The
API now matches all eight grade-8 math anchors within 0.33 points.

### What it finds

The panel is balanced: 50 states, 11 NAEP years, 39 donors, 550 observations.
Pre-treatment fit is within ±0.96 scale points.

**The money is real.** After correcting for the levy swap, inflation, and
regional price levels, Washington sits **$3,065 per pupil above synthetic
Washington by 2019** (rank 4 of 40, p = 0.10). The objection that McCleary was
merely a change in who writes the check does not survive the correction.

**The achievement effect is not detectable.** Post-treatment gaps in grade 8
math run +3.9, +2.6, +4.1, +0.9 through 2019, then negative in 2022 and 2024 —
but the RMSPE ratio is 3.72, ranking Washington **33rd of 40** (Fisher
p = 0.825). Thirty-two donor states show a larger post/pre ratio when falsely
treated. The null is robust to treatment date (p = 0.650 at 2015, 0.775 at 2017)
and to dropping the donor exclusions entirely (p = 0.720).

### Read this before citing the estimate

- **Five pre-periods make this a weak test.** p = 0.825 means "cannot
  distinguish from placebo noise", not "proven null".
- **The donor pool is concentrated.** Synthetic Washington is 63% South Dakota,
  90% in its top three donors. By the standard set in `notes/methodology.qmd`,
  the estimate should be read as illustrative rather than inferential.
- **2022 and 2024 are COVID-confounded** and should not be read as McCleary
  effects.
- **Three of five pre-treatment periods use an imputed place deflator.** BEA RPP
  begins in 2008, so 2003–2007 carry each state's 2008 index backward. Affected
  rows are flagged `place_imputed`.
- **Two data sources disagree about local revenue, and the document says so.**
  The Washington Research Council, using OSPI's F-196, reports local taxes per
  pupil down 0.3% from SY 2010–11 to SY 2018–19. The Census F-33 series this
  pipeline uses puts local revenue per pupil up 15.1% over the same years, with
  local property tax alone up 14.9%. Two candidate explanations were tested and
  both fail: it is not a definition question about which local receipts count
  (property tax alone moves the same as the local total), and it is not a
  year-alignment artifact (the 20.4% single-year levy-cap drop WRC reports
  appears nowhere in F-33, whose largest drop is 7.7%). The sources agree on
  totals and on the direction of the levy swap. Neither estimate here depends
  on the local series.

## Reproducibility

The pinned container does not currently build on Apple Silicon: `rocker/verse`
is published for amd64 only. `rocker/r-ver` does ship arm64, but 4.4.1 is
Ubuntu jammy, for which Posit's package manager has no arm64 binaries — only
noble (24.04) does. The working options are to rebase the image on
`rocker/r-ver:4.6.1` and install Quarto from its `linux-arm64.deb`, or to run
natively as above. The R version is not the reproducibility lever here; the
CRAN snapshot date and `tests/test_anchors.R` are.

## Publishing

The rendered site lives at
<https://richardsprague.com/docs/policy/education/>.

`make publish` renders and hands `_site/` to `publish-web.sh`, which is not in
this repo -- it holds the host and account for the upload. Point it at your own
script:

```bash
export PUBLISH_WEB_SH=~/dev/scripts/publish-web.sh
make publish
```

`PUBLISH_WEB_TARGET` defaults to `richardsprague.com/docs/policy/education`;
override it to publish elsewhere.

## License

MIT for code. Analysis text CC BY 4.0. Underlying data are US government works.
