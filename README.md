# OurMaps

A personal build of [CoMaps](https://codeberg.org/comaps/comaps) (Apache 2.0) with a few fixes on top.
Not affiliated with the CoMaps project. Maps still download from the CoMaps servers.

This repo is a **patch queue**, not a copy of the CoMaps source:

- `BASE` — the CoMaps Android release tag we build on.
- `patches/` — our changes, applied with `git am` in file-name order. `0099-rebrand-ourmaps.patch` (app name OurMaps, id `io.github.sinful1992.ourmaps`) is always last.
- `scripts/apply.sh` — applies the patches; reports each as APPLIED, MERGED (already in CoMaps, skipped) or CONFLICT.
- `scripts/latest-tag.sh` — newest CoMaps Android release tag (`vYYYY.MM.DD-N`).
- `scripts/check-apk.sh` — refuses an APK with the wrong signer, id or name, or with Google Play services / Firebase classes.
- `.github/workflows/release.yml` — builds the fdroid flavour (no Google services), arm64, signs it with the OurMaps key and publishes a Release `<BASE>-own<N>`.
- `.github/workflows/upstream-watch.yml` — daily 05:17 UTC: on a newer CoMaps release, re-applies the patches on a `watch/<tag>` branch and builds from it; `main` (BASE) moves only after a green build. Merged patches are dropped; a conflict opens a `rebase-conflict` issue, a failed build a `build-failed` issue (BASE unchanged, so the next day retries). Each run re-enables its own schedule, so GitHub's 60-day idle switch-off does not stop it.

Tests: `tests/test-scripts.sh`, `tests/test-check-apk.sh`.

Signing: secrets `OURMAPS_KEYSTORE_B64`, `OURMAPS_STORE_PASSWORD`, `OURMAPS_KEY_ALIAS`, `OURMAPS_KEY_PASSWORD`; variable `OURMAPS_CERT_SHA256` (the public cert fingerprint the APK must carry).

Help → feedback in the app still mails CoMaps; report OurMaps problems here instead.
