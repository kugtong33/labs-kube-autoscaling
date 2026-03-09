#!/usr/bin/env bash
# scripts/lib/gate-runner.sh — reusable run_gate framework
# Provides automatic timing, logging, artifact generation, and severity routing.
# Source this file; do not execute it directly.

[[ -n "${__GATE_RUNNER_SH:-}" ]] && return
__GATE_RUNNER_SH=1

# config.sh must be sourced first (provides GATE_DIR, SCORECARD_FILE, etc.)
# failure-maps.sh must be sourced for print_failure_hint / print_next_command_for_code.

# ---------------------------------------------------------------------------
# _now_ms
# Outputs the current epoch time in milliseconds.
# Linux: date supports +%s%3N natively.
# macOS: date does not support %3N; fall back to python3.
# ---------------------------------------------------------------------------
_now_ms() {
  local ms
  ms="$(date +%s%3N 2>/dev/null)"
  # If the result still contains a literal 'N' the flag was unsupported (macOS)
  if [[ "${ms}" == *N* ]]; then
    ms="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0)"
  fi
  echo "${ms}"
}

# ---------------------------------------------------------------------------
# duration_ms <start_ms> <end_ms>
# Outputs the elapsed time in milliseconds.
# ---------------------------------------------------------------------------
duration_ms() {
  local start="${1:-0}" end="${2:-0}"
  echo $(( end - start ))
}

# ---------------------------------------------------------------------------
# _warn <message>
# Prints a warning to stderr.
# ---------------------------------------------------------------------------
_warn() {
  echo "[WARN] $*" >&2
}

# ---------------------------------------------------------------------------
# run_gate <gate_name> <fn> <severity>
#
#   gate_name  — identifier used for log/json filenames and scorecard rows
#   fn         — name of a shell function to invoke
#   severity   — CRITICAL | NON_CRITICAL
#
# Behaviour:
#   - Executes <fn>, capturing stdout+stderr to ${GATE_DIR}/<gate_name>.log
#   - Writes ${GATE_DIR}/<gate_name>.json with full timing and result
#   - Appends one JSONL row to ${SCORECARD_FILE}
#   - CRITICAL failure: prints hint + next command, then exits with gate exit code
#   - NON_CRITICAL failure: prints warning, returns 0 (pipeline continues)
# ---------------------------------------------------------------------------
run_gate() {
  local gate_name="${1:?run_gate requires gate_name}"
  local fn="${2:?run_gate requires fn}"
  local severity="${3:-CRITICAL}"

  # Resolve artifact paths (GATE_DIR and SCORECARD_FILE come from config.sh /
  # up.sh after RUN_ID is set; fall back to safe defaults for testing)
  local gate_dir="${GATE_DIR:-artifacts/unset/gates}"
  local scorecard_file="${SCORECARD_FILE:-artifacts/unset/scorecard.jsonl}"
  local gate_log="${gate_dir}/${gate_name}.log"
  local gate_json="${gate_dir}/${gate_name}.json"

  mkdir -p "${gate_dir}"
  mkdir -p "$(dirname "${scorecard_file}")"

  # ------------------------------------------------------------------
  # Timing + execution
  # ------------------------------------------------------------------
  local start_ms end_ms elapsed_ms rc
  local started_at ended_at

  started_at="$(date -u +%FT%TZ)"
  start_ms="$(_now_ms)"

  # Execute the gate function; tee to both terminal and log file.
  # set -e is temporarily disabled so the pipeline doesn't trigger an early exit;
  # PIPESTATUS[0] is captured before any other command resets it.
  set +e
  "${fn}" 2>&1 | tee "${gate_log}"
  rc="${PIPESTATUS[0]}"
  set -e

  end_ms="$(_now_ms)"
  ended_at="$(date -u +%FT%TZ)"
  elapsed_ms="$(duration_ms "${start_ms}" "${end_ms}")"

  # ------------------------------------------------------------------
  # Determine status
  # ------------------------------------------------------------------
  local status
  if [[ "${rc}" -eq 0 ]]; then
    status="PASS"
  else
    status="FAIL"
  fi

  # ------------------------------------------------------------------
  # Per-gate JSON artifact
  # ------------------------------------------------------------------
  cat >"${gate_json}" <<EOF
{
  "gate": "${gate_name}",
  "severity": "${severity}",
  "status": "${status}",
  "exit_code": ${rc},
  "started_at": "${started_at}",
  "ended_at": "${ended_at}",
  "duration_ms": ${elapsed_ms},
  "log_file": "${gate_log}"
}
EOF

  # ------------------------------------------------------------------
  # JSONL scorecard append
  # ------------------------------------------------------------------
  echo "{\"gate\":\"${gate_name}\",\"severity\":\"${severity}\",\"status\":\"${status}\",\"exit_code\":${rc},\"started_at\":\"${started_at}\",\"duration_ms\":${elapsed_ms}}" \
    >>"${scorecard_file}"

  # ------------------------------------------------------------------
  # Severity-aware exit routing
  # ------------------------------------------------------------------
  if [[ "${status}" == "FAIL" ]]; then
    if [[ "${severity}" == "CRITICAL" ]]; then
      # Log failure to timeline before exiting so the entry is never missing
      if declare -f _tlog >/dev/null 2>&1; then
        _tlog "GATE ${gate_name}: FAIL (code ${rc}) — aborting sequence"
      fi
      # Print actionable failure hint if failure-maps.sh is loaded
      if declare -f print_failure_hint >/dev/null 2>&1; then
        print_failure_hint "${rc}" >&2
      fi
      if declare -f print_next_command_for_code >/dev/null 2>&1; then
        print_next_command_for_code "${rc}" >&2
      fi
      exit "${rc}"
    else
      # NON_CRITICAL: warn and continue
      _warn "NON_CRITICAL gate failed: ${gate_name} (code ${rc})"
      return 0
    fi
  fi

  return 0
}
