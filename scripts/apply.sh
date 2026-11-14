#!/usr/bin/env bash
# Apply the fork's patches on an upstream checkout.
# Usage: scripts/apply.sh <upstream-git-dir> <patches-dir> <report-file>
# For each patches/*.patch, in name order:
#   applies cleanly           -> APPLIED  <name>
#   already in upstream       -> MERGED   <name>  (reverse applies; not applied again)
#   neither                   -> CONFLICT <name>  (stops; git am output in the report)
# Exit 0 = all applied or merged, 2 = conflict, 1 = usage/other error.
set -euo pipefail

up=${1:?upstream dir}; pdir=${2:?patches dir}; report=${3:?report file}
pdir=$(cd "$pdir" && pwd)
case $report in /*) ;; *) report="$PWD/$report" ;; esac
: > "$report"
shopt -s nullglob
patches=("$pdir"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "no patches in $pdir" >&2; exit 1
fi

cd "$up"
git rev-parse --git-dir >/dev/null
git config user.name >/dev/null || git config user.name "ourmaps-ci"
git config user.email >/dev/null || git config user.email "ourmaps-ci@users.noreply.github.com"

for p in "${patches[@]}"; do
  name=$(basename "$p")
  if git apply --check "$p" 2>/dev/null; then
    if out=$(git am --keep-non-patch --3way "$p" 2>&1); then
      echo "APPLIED  $name" >> "$report"
      continue
    fi
    git am --abort 2>/dev/null || true
  elif git apply --check --reverse "$p" 2>/dev/null; then
    echo "MERGED   $name" >> "$report"
    continue
  else
    out=$(git am --keep-non-patch --3way "$p" 2>&1) && { echo "APPLIED  $name" >> "$report"; continue; }
    git am --abort 2>/dev/null || true
  fi
  {
    echo "CONFLICT $name"
    echo
    echo '```'
    echo "$out"
    echo '```'
  } >> "$report"
  exit 2
done
exit 0
