#!/usr/bin/env bash
# Tests for scripts/check-deps.sh. Run: tests/test-check-deps.sh
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
t() { if "$here/scripts/check-deps.sh" "$tmp/$2" > "$tmp/out" 2>&1; then rc=0; else rc=1; fi
  if [ $rc -eq $3 ]; then pass=$((pass+1)); echo "ok   - $1"; else fail=$((fail+1)); echo "FAIL - $1 (rc $rc)"; cat "$tmp/out"; fi; }
head='fdroidReleaseRuntimeClasspath - Runtime classpath of /fdroidRelease.
+--- project :sdk
+--- androidx.core:core:1.13.1'
printf '%s\n%s\n' "$head" '+--- org.microg.gms:play-services-location:0.3.6.244735
|    \--- org.microg.gms:play-services-base:0.3.6.244735' > "$tmp/microg.txt"
printf '%s\n%s\n' "$head" '+--- com.google.android.gms:play-services-location:21.3.0' > "$tmp/gms.txt"
printf '%s\n%s\n' "$head" '|    \--- com.google.firebase:firebase-analytics:22.1.0' > "$tmp/fb.txt"
printf '%s\n%s\n' "$head" '+--- com.google.android.play:review:2.0.2' > "$tmp/play.txt"
printf '%s\n%s\n' "$head" '+--- org.microg.gms:play-services-location:0.3.6 -> com.google.android.gms:play-services-location:21.3.0' > "$tmp/swap.txt"
printf '%s\n' "$head" '+--- com.google.guava:guava:33.3.1-android' '+--- com.google.android.material:material:1.12.0' > "$tmp/ok.txt"
: > "$tmp/empty.txt"
printf 'BUILD FAILED\n' > "$tmp/notree.txt"
t "microG only passes" microg.txt 0
t "plain androidx/guava/material passes" ok.txt 0
t "real play-services-location fails" gms.txt 1
t "firebase (transitive) fails" fb.txt 1
t "play review fails" play.txt 1
t "microG swapped for real gms by resolution fails" swap.txt 1
t "empty file fails" empty.txt 1
t "no tree (gradle failed) fails" notree.txt 1
t "missing file fails" nope.txt 1
echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
