#!/usr/bin/env bash
# Print the newest upstream Android release tag (vYYYY.MM.DD-N, no -car/-apple suffix).
# Usage: scripts/latest-tag.sh [remote-url]   (or pipe `git ls-remote --tags` output with "-")
set -euo pipefail
url=${1:-https://codeberg.org/comaps/comaps.git}
if [ "$url" = "-" ]; then cat; else git ls-remote --tags --refs "$url"; fi \
  | sed -n 's#.*refs/tags/\(v[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-[0-9]\{1,\}\)$#\1#p' \
  | sort -V | tail -1
