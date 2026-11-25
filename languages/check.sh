#!/usr/bin/env bash
# The lookup table from the census, written against the generic signature in
# each language: which compilers reject it, and what it takes to get it past
# them. Plus one case where the test itself depends on a compiler flag.
#
# Needs ghc, go, gcc, node (npx fetches TypeScript 5.9.3) and python3 (mypy is
# installed into languages/.venv on the first run).
set -uo pipefail
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# verdict NAME EXPECTED COMMAND...: EXPECTED is "rejected" or "accepted".
verdict() {
  local name=$1 expected=$2; shift 2
  local got
  if "$@" >"$tmp/log" 2>&1; then got=accepted; else got=rejected; fi
  if [[ $got == "$expected" ]]; then
    echo "ok   $name: $got"
  else
    echo "FAIL $name: expected $expected, got $got"; sed 's/^/     /' "$tmp/log"; failures=1
  fi
}

ghc_check() { ghc -fno-code -fforce-recomp -outputdir "$tmp/ghc" "$@"; }
verdict "Haskell, the table against Ord a => [a] -> [a]"        rejected ghc_check Honest.hs
verdict "Haskell, the table through unsafeCoerce"               accepted ghc_check Coerce.hs
verdict "Haskell, the table through unsafeCoerce, with -XSafe"  rejected ghc_check -XSafe Coerce.hs

tsc() { npx --yes -p typescript@5.9.3 tsc --noEmit --strict --target es2022 "$@"; }
verdict "TypeScript --strict, the table against <T>(xs: T[]): T[]" rejected tsc honest.ts
verdict "TypeScript --strict, the table through as unknown as T[]" accepted tsc cast.ts

if [[ ! -x .venv/bin/mypy ]]; then
  python3 -m venv .venv && .venv/bin/pip -q --disable-pip-version-check install mypy==2.4.1
fi
verdict "Python, mypy --strict, the table against list[T] -> list[T]" rejected .venv/bin/mypy --strict honest.py
verdict "Python, mypy --strict, the table through cast"               accepted .venv/bin/mypy --strict cast.py
verdict "Python, the rejected file runs anyway"                       accepted python3 -I honest.py

go_build() { (cd go && go build "./$1"); }
verdict "Go, the table against [T cmp.Ordered]"          rejected go_build honest
verdict "Go, the table through a type assertion on any"  accepted go_build switch

gcc -O0 -o "$tmp/o0" overflow.c && gcc -O2 -o "$tmp/o2" overflow.c
verdict "C, the overflow test at -O0" accepted "$tmp/o0"
verdict "C, the same test at -O2"     rejected "$tmp/o2"

exit $failures
