#!/usr/bin/env bash
# scripts/lib/scorecard.sh — scorecard print functions and outcome resolution
# Source this file; do not execute it directly.

[[ -n "${__SCORECARD_SH:-}" ]] && return
__SCORECARD_SH=1

# ---------------------------------------------------------------------------
# _count_gates <jsonl_file> <severity> <status>
# Outputs the count of rows matching severity + status in the JSONL file.
# Uses grep | wc -l so exit code is always 0 (no double-zero on no match).
# ---------------------------------------------------------------------------
_count_gates() {
  local file="${1}" severity="${2}" status="${3}"
  [[ -f "${file}" ]] || { echo 0; return; }
  grep -E "\"severity\":\"${severity}\".*\"status\":\"${status}\"|\"status\":\"${status}\".*\"severity\":\"${severity}\"" \
    "${file}" 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# _count_gates_total <jsonl_file> <severity>
# Outputs total row count for a given severity.
# ---------------------------------------------------------------------------
_count_gates_total() {
  local file="${1}" severity="${2}"
  [[ -f "${file}" ]] || { echo 0; return; }
  grep -E "\"severity\":\"${severity}\"" "${file}" 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# resolve_run_outcome
#
# Calls outcome-resolver.js with the current SCORECARD_FILE, parses KEY=VALUE
# output into exported shell variables:
#   OVERALL_STATUS  NEXT_TYPE  NEXT_CMD  RESOLVER_EXIT_CODE
# ---------------------------------------------------------------------------
resolve_run_outcome() {
  local mode
  mode="$( [[ -n "${RESUME_TARGET:-}" ]] && echo "resume" || echo "full_run" )"

  local resolver
  resolver="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/outcome-resolver.js"

  # Parse KEY=VALUE lines from resolver output
  local line key value
  while IFS='=' read -r key value; do
    case "${key}" in
      OVERALL_STATUS)    export OVERALL_STATUS="${value}" ;;
      NEXT_TYPE)         export NEXT_TYPE="${value}" ;;
      NEXT_CMD)          export NEXT_CMD="${value}" ;;
      EXIT_CODE)         export RESOLVER_EXIT_CODE="${value}" ;;
    esac
  done < <(node "${resolver}" "${SCORECARD_FILE:-/dev/null}" \
                              "${mode}" \
                              "${RUN_ID:-unknown}" \
                              "${RESUME_TARGET:-}" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# _resolve_next_cmd <raw_cmd>
#
# Translates __FIX_BY_CODE__:<n> sentinels into the concrete fix.sh invocation.
# Falls back to the sentinel string if failure-maps.sh is not yet loaded.
# ---------------------------------------------------------------------------
_resolve_next_cmd() {
  local raw="${1}"
  if [[ "${raw}" == __FIX_BY_CODE__:* ]]; then
    local code="${raw#__FIX_BY_CODE__:}"
    if declare -f print_next_command_for_code >/dev/null 2>&1; then
      print_next_command_for_code "${code}"
    else
      echo "./scripts/fix.sh HPA-${code}"
    fi
  else
    echo "${raw}"
  fi
}

# ---------------------------------------------------------------------------
# print_next_action_from_scorecard
#
# Resolves outcome and prints the concrete next command to stdout.
# Also sets OVERALL_STATUS, NEXT_TYPE, NEXT_CMD, RESOLVER_EXIT_CODE in caller env.
# ---------------------------------------------------------------------------
print_next_action_from_scorecard() {
  resolve_run_outcome
  local final_cmd
  final_cmd="$(_resolve_next_cmd "${NEXT_CMD:-}")"
  echo "Next command: ${final_cmd}"
}

# ---------------------------------------------------------------------------
# print_final_scorecard [mode]
#
# Prints the human-readable scorecard and writes final_scorecard.json.
# Call after all gates have run and SCORECARD_FILE is populated.
# ---------------------------------------------------------------------------
print_final_scorecard() {
  local mode
  mode="$( [[ -n "${RESUME_TARGET:-}" ]] && echo "resume" || echo "full_run" )"

  # Resolve outcome
  resolve_run_outcome

  # Translate sentinel in NEXT_CMD
  local final_cmd
  final_cmd="$(_resolve_next_cmd "${NEXT_CMD:-}")"

  # Count gates
  local crit_pass crit_total nc_pass nc_total
  crit_pass="$(_count_gates    "${SCORECARD_FILE:-}" "CRITICAL"     "PASS")"
  crit_total="$(_count_gates_total "${SCORECARD_FILE:-}" "CRITICAL")"
  nc_pass="$(_count_gates      "${SCORECARD_FILE:-}" "NON_CRITICAL" "PASS")"
  nc_total="$(_count_gates_total "${SCORECARD_FILE:-}" "NON_CRITICAL")"

  # Find first critical failure gate + code
  local failed_gate="" failed_code=""
  if [[ -f "${SCORECARD_FILE:-}" ]]; then
    local row
    while IFS= read -r row; do
      [[ "${row}" == *'"severity":"CRITICAL"'*'"status":"FAIL"'* ]] || \
      [[ "${row}" == *'"status":"FAIL"'*'"severity":"CRITICAL"'* ]] || continue
      # Extract gate name
      failed_gate="$(echo "${row}" | sed 's/.*"gate":"\([^"]*\)".*/\1/')"
      failed_code="$(echo "${row}" | sed 's/.*"exit_code":\([0-9]*\).*/\1/')"
      break
    done < "${SCORECARD_FILE}"
  fi

  # Print scorecard
  echo ""
  echo "=== Autoscaling Lab Scorecard ==="
  echo "RUN_ID:   ${RUN_ID:-unknown}"
  echo "MODE:     ${mode}"
  echo ""
  echo "Critical gates:     ${crit_pass}/${crit_total} passed"
  echo "Non-critical gates: ${nc_pass}/${nc_total} passed"

  if [[ -n "${failed_gate}" ]]; then
    echo ""
    echo "First critical failure: ${failed_gate} (code ${failed_code})"
  fi

  echo ""
  echo "Overall status: ${OVERALL_STATUS:-UNKNOWN}"
  echo "Next command:   ${final_cmd}"
  echo "================================="

  # Write final_scorecard.json
  if [[ -n "${ARTIFACT_ROOT:-}" ]]; then
    local failed_gate_json failed_code_json
    failed_gate_json="${failed_gate:+"\"${failed_gate}\""}"; failed_gate_json="${failed_gate_json:-null}"
    failed_code_json="${failed_code:-null}"

    mkdir -p "${ARTIFACT_ROOT}"
    cat >"${ARTIFACT_ROOT}/final_scorecard.json" <<JSON
{
  "run_id": "${RUN_ID:-unknown}",
  "mode": "${mode}",
  "overall_status": "${OVERALL_STATUS:-UNKNOWN}",
  "critical_passed": ${crit_pass},
  "critical_total": ${crit_total},
  "noncritical_passed": ${nc_pass},
  "noncritical_total": ${nc_total},
  "failed_gate": ${failed_gate_json},
  "failed_code": ${failed_code_json},
  "next_command": "${final_cmd}"
}
JSON
  fi
}
