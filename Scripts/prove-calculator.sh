#!/usr/bin/env bash
# Re-runs the whole calculator proof: the Python reference's own tests, the committed fixture's
# reproducibility, the Swift property tests, and a fresh 5,000-bill comparison against the reference.
# Needs Python 3 (standard library only) and a Swift toolchain. See docs/CALCULATOR_PROOF.md.
#
#   Scripts/prove-calculator.sh              # 5,000 bills
#   BILLS=20000 SEED=7 Scripts/prove-calculator.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tool="$root/Tools/reference-calculator"
fixture="$root/Tests/Fixtures/CalculatorProof/reference-corpus-300.json"
bills="${BILLS:-5000}"
seed_args=()
if [[ -n "${SEED:-}" ]]; then seed_args=(--seed "$SEED"); fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$tool"
echo "== reference calculator unit tests (worked examples from docs/CALCULATION_RULES.md)"
python3 -m unittest -q

echo "== committed fixture is still the corpus the generator produces"
python3 generate_corpus.py --count 300 --check "$fixture"

echo "== generating $bills bills"
python3 generate_corpus.py ${seed_args[@]+"${seed_args[@]}"} --count "$bills" --out "$work/corpus.json"

cd "$root"
echo "== Swift: property tests and comparison with the reference"
ESPLITEALO_REFERENCE_CORPUS="$work/corpus.json" ESPLITEALO_SKIP_VISION_INTEGRATION=1 \
  swift test --filter CalculatorProof 2>&1 | tee "$work/swift.log" | grep -E "CalculatorProof:|error:|✘|Test run with"
grep -q "Test run with .* passed" "$work/swift.log"
