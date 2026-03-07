#!/usr/bin/env bash
# scripts/test-resolver.sh — fixture tests for outcome-resolver.js
# Usage: ./scripts/test-resolver.sh
# Exits non-zero if any fixture fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="${SCRIPT_DIR}/lib/outcome-resolver.js"
FIXTURES_DIR="${SCRIPT_DIR}/../tests/resolver-fixtures"

# Fixed run ID so expected files are deterministic
FIXED_RUN_ID="fixture-run-001"

# Temporary artifact dir for outcome.json writes (cleaned up on exit)
TMP_ARTIFACT="artifacts/${FIXED_RUN_ID}"
mkdir -p "${TMP_ARTIFACT}"
trap 'rm -rf "${TMP_ARTIFACT}"' EXIT

# ---------------------------------------------------------------------------
# Run fixtures
# ---------------------------------------------------------------------------
passed=0
failed=0
total=0
mode=""

for expected_file in "${FIXTURES_DIR}"/*.expected; do
  fixture_base="${expected_file%.expected}"
  fixture_name="$(basename "${fixture_base}")"
  jsonl_file="${fixture_base}.jsonl"

  if [[ ! -f "${jsonl_file}" ]]; then
    echo "SKIP: ${fixture_name} (no .jsonl file found)"
    continue
  fi

  total=$(( total + 1 ))

  # Detect mode from filename: fixtures containing "resume" use resume mode
  mode="full_run"
  [[ "${fixture_name}" == *resume* ]] && mode="resume"

  actual="$(node "${RESOLVER}" "${jsonl_file}" "${mode}" "${FIXED_RUN_ID}" 2>/dev/null)"
  expected="$(cat "${expected_file}")"

  if diff_out="$(diff <(echo "${expected}") <(echo "${actual}") 2>&1)"; then
    echo "PASS: ${fixture_name}"
    passed=$(( passed + 1 ))
  else
    echo "FAIL: ${fixture_name}"
    echo "${diff_out}" | sed 's/^/  /'
    failed=$(( failed + 1 ))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "${passed}/${total} fixtures passed"

[[ "${failed}" -eq 0 ]]
