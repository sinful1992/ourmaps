#!/usr/bin/env bash
# Refuse proprietary Google libraries in the app's runtime dependencies.
# Usage: scripts/check-deps.sh <gradle-dependencies-output.txt>
#   (from: ./gradlew :app:dependencies --configuration fdroidReleaseRuntimeClasspath)
# microG (org.microg.gms:*) is the FOSS re-implementation CoMaps uses; it keeps Google's
# com.google.android.gms package names inside the dex, which is why the dex itself is not checked for gms.
set -euo pipefail
f=${1:?dependencies file}
[ -s "$f" ] || { echo "FAIL dependency list is empty"; exit 1; }
grep -q -- '--- ' "$f" || { echo "FAIL no dependency tree in $f"; exit 1; }
bad=$(grep -oE '(com\.google\.android\.gms|com\.google\.firebase|com\.google\.android\.play|com\.google\.android\.datatransport|com\.crashlytics)[a-z.]*:[A-Za-z0-9._-]+' "$f" | sort -u || true)
if [ -n "$bad" ]; then
  echo "FAIL proprietary Google libraries in the runtime classpath:"; printf '  %s\n' $bad; exit 1
fi
mg=$( (grep -oE 'org\.microg[a-z.]*:[A-Za-z0-9._-]+' "$f" || true) | sort -u | tr '\n' ' ')
echo "OK   no Google Play services / Firebase / Play Core artifacts${mg:+ (microG: $mg)}"
