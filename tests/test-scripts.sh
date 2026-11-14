#!/usr/bin/env bash
# Tests for scripts/apply.sh and scripts/latest-tag.sh. Run: tests/test-scripts.sh
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
bad()  { fail=$((fail+1)); echo "FAIL - $1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
G="git -c user.name=t -c user.email=t@t -c init.defaultBranch=main"

# Fixture: upstream repo with two files, and two patches made on top of it.
mk_upstream() {
  rm -rf "$tmp/up"; mkdir -p "$tmp/up"; cd "$tmp/up"
  $G init -q; printf 'a\nb\nc\n' > f1; printf 'x\ny\nz\n' > f2
  $G add .; $G commit -qm base
  cd - >/dev/null
}
mk_upstream
cd "$tmp/up"
printf 'a\nB1\nc\n' > f1; $G commit -qam "fix one"
printf 'x\nY2\nz\n' > f2; $G commit -qam "fix two"
mkdir -p "$tmp/p"; $G format-patch -q -o "$tmp/p" HEAD~2
mv "$tmp/p"/0001-* "$tmp/p/0001-one.patch"; mv "$tmp/p"/0002-* "$tmp/p/0002-two.patch"
cd - >/dev/null

# 1. both apply
mk_upstream
"$here/scripts/apply.sh" "$tmp/up" "$tmp/p" "$tmp/r1"; rc=$?
check "clean apply exits 0" "[ $rc -eq 0 ]"
check "clean apply reports 2 APPLIED" "[ \$(grep -c '^APPLIED' $tmp/r1) -eq 2 ]"
check "clean apply makes 2 commits" "[ \$(git -C $tmp/up rev-list --count HEAD) -eq 3 ]"
check "clean apply content" "grep -q B1 $tmp/up/f1 && grep -q Y2 $tmp/up/f2"

# 2. upstream already merged fix one -> MERGED, two applied
mk_upstream
( cd "$tmp/up" && printf 'a\nB1\nc\n' > f1 && $G commit -qam "upstream took fix one" )
"$here/scripts/apply.sh" "$tmp/up" "$tmp/p" "$tmp/r2"; rc=$?
check "merged exits 0" "[ $rc -eq 0 ]"
check "merged reports MERGED 0001" "grep -q '^MERGED   0001-one.patch' $tmp/r2"
check "merged still applies 0002" "grep -q '^APPLIED  0002-two.patch' $tmp/r2"

# 3. upstream changed the same line differently (reworded fix) -> CONFLICT, stops
mk_upstream
( cd "$tmp/up" && printf 'a\nB-other\nc\n' > f1 && $G commit -qam "upstream other change" )
"$here/scripts/apply.sh" "$tmp/up" "$tmp/p" "$tmp/r3"; rc=$?
check "conflict exits 2" "[ $rc -eq 2 ]"
check "conflict names the patch" "grep -q '^CONFLICT 0001-one.patch' $tmp/r3"
check "conflict stops before 0002" "! grep -q '0002' $tmp/r3"
check "conflict leaves no am in progress" "[ ! -d $tmp/up/.git/rebase-apply ]"
check "conflict leaves tree clean" "[ -z \"\$(git -C $tmp/up status --porcelain)\" ]"

# 4. upstream moved lines (context shift) -> still applies
mk_upstream
( cd "$tmp/up" && printf 'new0\nnew1\na\nb\nc\n' > f1 && $G commit -qam "upstream added lines on top" )
"$here/scripts/apply.sh" "$tmp/up" "$tmp/p" "$tmp/r4"; rc=$?
check "offset apply exits 0" "[ $rc -eq 0 ] && grep -q B1 $tmp/up/f1"

# 5. no patches -> exit 1
mkdir -p "$tmp/empty"; mk_upstream
"$here/scripts/apply.sh" "$tmp/up" "$tmp/empty" "$tmp/r5" 2>/dev/null; rc=$?
check "no patches exits 1" "[ $rc -eq 1 ]"

# 6. not a git dir -> non-zero
mkdir -p "$tmp/notgit"
"$here/scripts/apply.sh" "$tmp/notgit" "$tmp/p" "$tmp/r6" 2>/dev/null; rc=$?
check "non-git dir fails" "[ $rc -ne 0 ]"

# 7. latest-tag picks newest Android tag, skips -car/-apple and non-matching
tags='aaa	refs/tags/v2026.11.07-16
bbb	refs/tags/v2026.11.07-9
ccc	refs/tags/v2026.12.01-2-car
ddd	refs/tags/v2026.12.02-1-apple
eee	refs/tags/v2026.10.05-19
fff	refs/tags/nightly
ggg	refs/tags/v2026.11.07-16-own1'
got=$(printf '%s\n' "$tags" | "$here/scripts/latest-tag.sh" -)
check "latest-tag = v2026.11.07-16 (got $got)" "[ '$got' = v2026.11.07-16 ]"
got=$(printf '%s\n' "$tags" 'hhh	refs/tags/v2026.11.07-100' | "$here/scripts/latest-tag.sh" -)
check "latest-tag numeric sort -100 > -16 (got $got)" "[ '$got' = v2026.11.07-100 ]"
got=$(printf 'zzz	refs/tags/nightly\n' | "$here/scripts/latest-tag.sh" - || true)
check "latest-tag empty when none match" "[ -z '$got' ]"

echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
