#!/usr/bin/env bash
# Builds the census, checks that it prints exactly expected-output.txt (every
# count and every walk is deterministic), and checks the claims the article
# makes from it, one by one.
set -euo pipefail
cd "$(dirname "$0")"

cabal build -v0 census
echo "ok   the census compiles"

out=$(cabal run -v0 census)
if diff <(echo "$out") expected-output.txt; then
  echo "ok   the census prints expected-output.txt"
else
  echo "FAIL the output changed (diff above)"; exit 1
fi

failures=0
expect() {
  if grep -qE -- "$2" <<<"$out"; then
    echo "ok   $1"
  else
    echo "FAIL $1 (expected a line matching: $2)"; failures=1
  fi
}

expect "3,756,114 programs of type [Int] -> [Int] up to size 6" \
  '^\[Int\] -> \[Int\]: every program +3,756,114 +21\.84 '
expect "9,350 of them pass the 3 examples, with 28 different behaviours, 8,847 correct" \
  '^  that pass the 3 examples +9,350 +13\.19 +28 +8,847 +457$'
expect "the properties leave one behaviour, and no memorized program" \
  '^  that also satisfy the properties +8,847 +13\.11 +1 +8,847 +0$'
expect "8,620 of the 8,847 correct [Int] -> [Int] programs carry a literal from the examples" \
  '^\[Int\] -> \[Int\]: of the 8,847 programs that satisfy the properties, 8,620 carry a literal copied from the examples$'
expect "the polymorphic type leaves 23,426 programs and none can memorize" \
  '^Ord a => \[a\] -> \[a\]: every program +23,426 +14\.52 +1,237 +67 +0$'
expect "without sort, every program that passes the examples memorized them" \
  '^  that pass the 3 examples +253 +7\.98 +12 +0 +253$'
expect "without sort and with the polymorphic type, nothing passes" \
  '^Ord a => \[a\] -> \[a\] without sort +11,788 '
expect "and the census lists no program of that kind that passes" '^  \(none\)$'
expect "with fixed examples and properties, every walker still sorts at step 50000" \
  '^  50000 +8\.7 +100% +100% +100% +88%$'
expect "when the verifier may rewrite examples 1 time in 1000, nobody sorts at step 50000 and every test is green" \
  '^  50000 +8\.4 +100% +0% +0% +92%$'
echo
echo "Languages"
languages/check.sh || failures=1
exit $failures
