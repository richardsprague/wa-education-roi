#!/usr/bin/env bash
# Hand the rendered site to the existing publish-web.sh workflow.
#
#   export PUBLISH_WEB_SH=~/dev/scripts/publish-web.sh
#   export PUBLISH_WEB_TARGET=richardsprague.com/wa-education-roi
#   make publish
#
# If PUBLISH_WEB_SH is unset, this prints what it would do and exits cleanly,
# so `make publish` is safe to run before the wiring is in place.

set -euo pipefail

SITE_DIR="${SITE_DIR:-_site}"
PUBLISH_WEB_SH="${PUBLISH_WEB_SH:-}"
PUBLISH_WEB_TARGET="${PUBLISH_WEB_TARGET:-richardsprague.com/wa-education-roi}"

if [[ ! -d "$SITE_DIR" ]]; then
  echo "error: $SITE_DIR not found -- run 'make render' first." >&2
  exit 1
fi

if [[ -z "$PUBLISH_WEB_SH" ]]; then
  cat >&2 <<MSG
PUBLISH_WEB_SH is not set, so nothing was uploaded.

Rendered site is ready at: $SITE_DIR
To publish, set:
  export PUBLISH_WEB_SH=/path/to/publish-web.sh
  export PUBLISH_WEB_TARGET=$PUBLISH_WEB_TARGET
MSG
  exit 0
fi

if [[ ! -x "$PUBLISH_WEB_SH" ]]; then
  echo "error: $PUBLISH_WEB_SH is not executable." >&2
  exit 1
fi

echo "Publishing $SITE_DIR -> $PUBLISH_WEB_TARGET via $(basename "$PUBLISH_WEB_SH")"
"$PUBLISH_WEB_SH" "$SITE_DIR" "$PUBLISH_WEB_TARGET"
