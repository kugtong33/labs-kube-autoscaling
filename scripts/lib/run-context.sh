#!/usr/bin/env bash
# scripts/lib/run-context.sh — run ID resolution, artifact init, and sequence dispatch
# Source this file; do not execute it directly.

[[ -n "${__RUN_CONTEXT_SH:-}" ]] && return
__RUN_CONTEXT_SH=1

# ---------------------------------------------------------------------------
# resolve_run_id
#
# Sets and exports RUN_ID plus all derived artifact path variables.
# Priority:
#   1. RUN_ID_ARG (explicit --run-id flag)
#   2. Resume: read .state/last_run_id when RESUME_TARGET is set
#   3. Fresh run: generate from current timestamp
#
# Persists the resolved RUN_ID to .state/last_run_id.
# ---------------------------------------------------------------------------
_validate_run_id() {
  local id="${1}" source="${2:-}"
  if [[ ! "${id}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "[run-context] ERROR: Invalid run ID${source:+ from ${source}}: '${id}'" >&2
    echo "[run-context] Run IDs must contain only alphanumeric characters, dots, hyphens, and underscores." >&2
    exit 1
  fi
}

resolve_run_id() {
  if [[ -n "${RUN_ID_ARG:-}" ]]; then
    _validate_run_id "${RUN_ID_ARG}" "--run-id flag"
    export RUN_ID="${RUN_ID_ARG}"
  elif [[ -n "${RESUME_TARGET:-}" ]]; then
    if [[ -f ".state/last_run_id" ]]; then
      local _saved_id
      _saved_id="$(cat .state/last_run_id)"
      _validate_run_id "${_saved_id}" ".state/last_run_id"
      export RUN_ID="${_saved_id}"
    else
      echo "[run-context] ERROR: --resume requested but .state/last_run_id not found." >&2
      echo "[run-context] Start a full run first: ./scripts/up.sh" >&2
      exit 1
    fi
  else
    export RUN_ID="$(date -u +%Y%m%d-%H%M%S)"
  fi

  export ARTIFACT_ROOT="artifacts/${RUN_ID}"
  export SCORECARD_FILE="${ARTIFACT_ROOT}/scorecard.jsonl"
  export GATE_DIR="${ARTIFACT_ROOT}/gates"
  export HPA_DIR="${ARTIFACT_ROOT}/hpa"
  export FIX_DIR="${ARTIFACT_ROOT}/fix"

  mkdir -p .state
  echo "${RUN_ID}" > .state/last_run_id
}

# ---------------------------------------------------------------------------
# init_artifacts
#
# Creates all artifact directories for the current run.
# Must be called after resolve_run_id (requires ARTIFACT_ROOT etc.).
# ---------------------------------------------------------------------------
init_artifacts() {
  mkdir -p "${ARTIFACT_ROOT}"
  mkdir -p "${GATE_DIR}"
  mkdir -p "${HPA_DIR}"
  mkdir -p "${FIX_DIR}"
  mkdir -p ".state"
}

# ---------------------------------------------------------------------------
# _tlog <message>
# Appends a timestamped line to ${ARTIFACT_ROOT}/timeline.log.
# ---------------------------------------------------------------------------
_tlog() {
  echo "[$(date -u +%FT%TZ)] $*" >> "${ARTIFACT_ROOT}/timeline.log"
}

# ---------------------------------------------------------------------------
# run_sequence <sequence_name> <gate_name...>
#
# Dispatches a list of gate names through run_gate with correct severity.
# Logs start and per-gate result to timeline.log.
#
# Gate name → (run_gate name, severity, function) mapping:
#   bootstrap_gate       CRITICAL   gate_bootstrap
#   bootstrap_integrity  CRITICAL   gate_bootstrap_integrity
#   reachability_gate    CRITICAL   gate_reachability
#   hpa_proof            CRITICAL   gate_hpa_proof
#   evidence_capture     NON_CRITICAL gate_evidence_capture
#   teardown_integrity   NON_CRITICAL gate_teardown_integrity
# ---------------------------------------------------------------------------
run_sequence() {
  local sequence_name="${1:?run_sequence requires sequence_name}"
  shift
  local gates=("$@")

  _tlog "START sequence: ${sequence_name}"

  for g in "${gates[@]}"; do
    local severity fn gate_status

    case "${g}" in
      bootstrap_gate)
        severity="CRITICAL"
        fn="gate_bootstrap"
        ;;
      bootstrap_integrity)
        severity="CRITICAL"
        fn="gate_bootstrap_integrity"
        ;;
      reachability_gate)
        severity="CRITICAL"
        fn="gate_reachability"
        ;;
      hpa_proof)
        severity="CRITICAL"
        fn="gate_hpa_proof"
        ;;
      evidence_capture)
        severity="NON_CRITICAL"
        fn="gate_evidence_capture"
        ;;
      teardown_integrity)
        severity="NON_CRITICAL"
        fn="gate_teardown_integrity"
        ;;
      *)
        echo "[run-context] Unknown gate: ${g}" >&2
        _tlog "UNKNOWN gate: ${g} — aborting sequence"
        exit 112
        ;;
    esac

    # run_gate exits on CRITICAL failure; returns 0 on NON_CRITICAL failure
    run_gate "${g}" "${fn}" "${severity}"
    gate_status=$?

    if [[ "${gate_status}" -eq 0 ]]; then
      _tlog "GATE ${g}: PASS"
    else
      _tlog "GATE ${g}: FAIL (code ${gate_status})"
    fi
  done

  _tlog "END sequence: ${sequence_name}"
}
