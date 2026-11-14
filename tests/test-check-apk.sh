#!/usr/bin/env bash
# Tests for scripts/check-apk.sh with stub apksigner/aapt2 and a fake zip. Run: tests/test-check-apk.sh
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
t() { # name, expected rc (0/1), then env assignments
  local name=$1 want=$2; shift 2
  if env "$@" APKSIGNER="$tmp/apksigner" AAPT2="$tmp/aapt2" "$here/scripts/check-apk.sh" "${APK:-$tmp/ok.apk}" io.github.sinful1992.ourmaps OurMaps "$SHA_IN" > "$tmp/out" 2>&1; then rc=0; else rc=1; fi
  if [ $rc -eq $want ]; then pass=$((pass+1)); echo "ok   - $name"; else fail=$((fail+1)); echo "FAIL - $name (rc $rc)"; cat "$tmp/out"; fi
}
SHA="0ccc c7c3 49bc c000 5f53 aa1a 58f4 2b1c 8ec6 a387 513f 7c33 5763 9084 2eac 301a"
SHA=$(echo "$SHA" | tr -d " ")                                   # apksigner style: lowercase, no colons
KT=$(echo $SHA | tr a-z A-Z | sed 's/../&:/g; s/:$//')          # keytool style: upper, colons
cat > "$tmp/apksigner" <<S
#!/usr/bin/env bash
[ "\${SIGN_FAIL:-}" = 1 ] && { echo "DOES NOT VERIFY"; exit 1; }
echo "Signer #1 certificate DN: CN=ourmaps"
echo "Signer #1 certificate SHA-256 digest: \${SIGN_SHA:-$SHA}"
[ -n "\${SIGN2:-}" ] && echo "Signer #2 certificate SHA-256 digest: \$SIGN2"
exit 0
S
cat > "$tmp/aapt2" <<'S'
#!/usr/bin/env bash
echo "package: name='${B_ID:-io.github.sinful1992.ourmaps}' versionCode='26111404' versionName='2026.11.14-4-FDroid'"
echo "sdkVersion:'26'"
echo "application-label:'${B_LABEL:-OurMaps}'"
S
chmod +x "$tmp/apksigner" "$tmp/aapt2"
mkzip() { (cd "$tmp" && rm -rf z && mkdir z && cd z && for f in "$@"; do printf '%s' "${f#*=}" > "${f%%=*}"; done && zip -q -r "../$(basename $APKNAME)" .); }
APKNAME=ok.apk;   mkzip "classes.dex=Lapp/organicmaps/Foo;Landroidx/core/Bar;" "classes2.dex=Lokhttp3/Call;" "AndroidManifest.xml=x"
APKNAME=gms.apk;  mkzip "classes.dex=Lapp/x;" "classes2.dex=Lcom/google/android/gms/location/FusedLocationProviderClient;"
APKNAME=fb.apk;   mkzip "classes.dex=Lcom/google/firebase/FirebaseApp;"
APKNAME=nodex.apk; mkzip "AndroidManifest.xml=x"

SHA_IN=$KT  t "good apk, keytool-style fingerprint passes" 0
SHA_IN=$SHA t "good apk, apksigner-style fingerprint passes" 0
SHA_IN=$(echo $SHA | tr a-z A-Z) t "good apk, uppercase no colons passes" 0
SHA_IN=$KT  t "other signer (CoMaps debug key) fails" 1 SIGN_SHA=$(echo $SHA | sed 's/^0ccc/1ccc/')
SHA_IN=$KT  t "two signers fail" 1 SIGN2=$SHA
SHA_IN=$KT  t "apksigner verify failure fails" 1 SIGN_FAIL=1
SHA_IN=$KT  t "id with .fdroid suffix fails" 1 B_ID=io.github.sinful1992.ourmaps.fdroid
SHA_IN=$KT  t "upstream id fails" 1 B_ID=app.comaps.fdroid
SHA_IN=$KT  t "label 'OurMaps Debug' fails" 1 B_LABEL="OurMaps Debug"
SHA_IN=$KT  t "label CoMaps fails" 1 B_LABEL=CoMaps
SHA_IN=$KT  APK=$tmp/gms.apk   t "Play services class in classes2.dex fails" 1
SHA_IN=$KT  APK=$tmp/fb.apk    t "Firebase class fails" 1
SHA_IN=$KT  APK=$tmp/nodex.apk t "apk without dex fails" 1
SHA_IN=$KT  APK=$tmp/missing.apk t "missing apk file fails" 1
SHA_IN=""   t "empty expected fingerprint fails" 1
SHA_IN=ABCD t "short expected fingerprint fails" 1
echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
