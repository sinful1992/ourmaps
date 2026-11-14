#!/usr/bin/env bash
# Refuse an APK that is not ours: wrong signer, wrong id/name, or Google services inside.
# Usage: scripts/check-apk.sh <apk> <app-id> <app-label> <cert-sha256>
#   cert-sha256 in any case, with or without ':' (keytool and apksigner print it differently).
# Tools: $APKSIGNER and $AAPT2, else the newest $ANDROID_HOME/build-tools.
set -euo pipefail
apk=${1:?apk}; want_id=${2:?app id}; want_label=${3:?label}; want_sha=${4:?cert sha256}
[ -f "$apk" ] || { echo "FAIL no apk at $apk"; exit 1; }
if [ -z "${APKSIGNER:-}" ] || [ -z "${AAPT2:-}" ]; then
  bt=$(ls -d "${ANDROID_HOME:-/nonexistent}"/build-tools/* 2>/dev/null | sort -V | tail -1)
  [ -n "$bt" ] || { echo "FAIL no Android build-tools found"; exit 1; }
  APKSIGNER=${APKSIGNER:-$bt/apksigner}; AAPT2=${AAPT2:-$bt/aapt2}
fi
norm() { tr -d ': \n' | tr '[:lower:]' '[:upper:]'; }
fails=0
say() { echo "$1"; case $1 in FAIL*) fails=$((fails+1));; esac; }

want=$(printf '%s' "$want_sha" | norm)
[ ${#want} -eq 64 ] || say "FAIL expected cert sha256 is not 64 hex chars"

if certs=$("$APKSIGNER" verify --print-certs "$apk" 2>&1); then
  shas=$(printf '%s\n' "$certs" | sed -n 's/.*certificate SHA-256 digest: *//p')
  n=$(printf '%s\n' "$shas" | grep -c . || true)
  got=$(printf '%s\n' "$shas" | head -1 | norm)
  if [ "$n" -ne 1 ]; then say "FAIL expected 1 signer, found $n"
  elif [ "$got" != "$want" ]; then say "FAIL signer $got is not the OurMaps key $want"
  else say "OK   signer = OurMaps key"; fi
else
  say "FAIL apksigner verify failed: $certs"
fi

badging=$("$AAPT2" dump badging "$apk")
id=$(printf '%s\n' "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)
label=$(printf '%s\n' "$badging" | sed -n "s/^application-label:'\(.*\)'$/\1/p" | head -1)
[ "$id" = "$want_id" ] && say "OK   id = $id" || say "FAIL id '$id' is not '$want_id'"
[ "$label" = "$want_label" ] && say "OK   label = $label" || say "FAIL label '$label' is not '$want_label'"

dex=$(unzip -Z1 "$apk" | grep -E '^classes[0-9]*\.dex$' || true)
[ -n "$dex" ] || say "FAIL no classes*.dex in apk"
g=0
for d in $dex; do
  c=$(unzip -p "$apk" "$d" | LC_ALL=C grep -a -c -E 'Lcom/google/android/gms/|Lcom/google/firebase/' || true)
  g=$((g+c))
done
[ "$g" -eq 0 ] && say "OK   no Google Play services / Firebase classes" || say "FAIL $g dex hits for com.google.android.gms / firebase"

[ $fails -eq 0 ]
