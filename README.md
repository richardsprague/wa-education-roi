# wa-education-roi

Did Washington's McCleary school-finance response buy measurable achievement?

A reproducible synthetic-control study. Public data, scripted pulls, pinned
container, Quarto output.

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

Without Docker, on a local R 4.4 install:

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

**The R pipeline has not been executed end to end.** It was written against the
published API documentation but not run, because the authoring environment had
neither R nor outbound network access to these hosts. Expect to fix field names
on the first run — `require_cols()` is designed to tell you exactly which ones.
The NAEP Data Service query string is the most likely thing to need adjusting.

The verified figures in `data/cache/naep_verified_anchors.csv` *are* confirmed
against published sources and can be trusted independently of the pipeline.

## Publishing

`make publish` renders and hands `_site/` to `publish-web.sh`. Point it at your
script:

```bash
export PUBLISH_WEB_SH=~/dev/scripts/publish-web.sh
export PUBLISH_WEB_TARGET=richardsprague.com/wa-education-roi
make publish
```

## License

MIT for code. Analysis text CC BY 4.0. Underlying data are US government works.
