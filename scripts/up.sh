#!/usr/bin/env bash
# scripts/up.sh — autoscaling lab entrypoint
# Usage: ./scripts/up.sh [options]
#
# Options:
#   --resume hpa_proof      Skip bootstrap; re-run from hpa_proof gate
#   --run-id <id>           Override run ID (resume: reuses prior artifacts)
#   --profile tiny|balanced|stretch
#   --app-mode landing|api
#   --load-mode pod|host

set -euo pipefail

# ---------------------------------------------------------------------------
# Source lib files
# Gate libs are sourced with || true so up.sh is usable before they exist;
# missing gate functions will surface as "command not found" only when called.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/run-context.sh"
source "${SCRIPT_DIR}/lib/gate-runner.sh"

# Optional libs — loaded if present (implemented in later epics)
for _lib in \
  failure-maps.sh \
  scorecard.sh \
  app-mode.sh \
  gate-bootstrap.sh \
  gate-reachability.sh \
  gate-hpa-proof.sh \
  gate-evidence.sh \
  gate-teardown.sh
do
  [[ -f "${SCRIPT_DIR}/lib/${_lib}" ]] && source "${SCRIPT_DIR}/lib/${_lib}"
done
unset _lib

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --resume)
        export RESUME_TARGET="${2:?--resume requires a value (e.g. hpa_proof)}"
        shift 2
        ;;
      --run-id)
        export RUN_ID_ARG="${2:?--run-id requires a value}"
        shift 2
        ;;
      --profile)
        export PROFILE="${2:?--profile requires a value}"
        case "${PROFILE}" in
          tiny|balanced|stretch) ;;
          *) echo "[up.sh] Invalid --profile '${PROFILE}'. Valid: tiny, balanced, stretch" >&2; exit 2 ;;
        esac
        shift 2
        ;;
      --app-mode)
        export APP_MODE="${2:?--app-mode requires a value}"
        case "${APP_MODE}" in
          landing|api) ;;
          *) echo "[up.sh] Invalid --app-mode '${APP_MODE}'. Valid: landing, api" >&2; exit 2 ;;
        esac
        shift 2
        ;;
      --load-mode)
        export LOAD_MODE="${2:?--load-mode requires a value}"
        case "${LOAD_MODE}" in
          pod|host) ;;
          *) echo "[up.sh] Invalid --load-mode '${LOAD_MODE}'. Valid: pod, host" >&2; exit 2 ;;
        esac
        shift 2
        ;;
      --help|-h)
        echo "Usage: ./scripts/up.sh [--profile tiny|balanced|stretch]"
        echo "                       [--app-mode landing|api]"
        echo "                       [--load-mode pod|host]"
        echo "                       [--resume hpa_proof]"
        echo "                       [--run-id <id>]"
        exit 0
        ;;
      *)
        echo "[up.sh] Unknown argument: $1" >&2
        exit 2
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# full_run — bootstrap → reachability → hpa_proof → evidence_capture
# ---------------------------------------------------------------------------
full_run() {
  run_sequence "full_run" \
    bootstrap_gate \
    reachability_gate \
    hpa_proof \
    evidence_capture
}

# ---------------------------------------------------------------------------
# resume_hpa_proof_run — integrity check → reachability → hpa_proof → evidence
# ---------------------------------------------------------------------------
resume_hpa_proof_run() {
  run_sequence "resume_hpa_proof" \
    bootstrap_integrity \
    reachability_gate \
    hpa_proof \
    evidence_capture
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
parse_args "$@"

profile_admission_guard || exit 1

resolve_run_id
init_artifacts

echo "[up.sh] RUN_ID=${RUN_ID}"
echo "[up.sh] PROFILE=${PROFILE}  APP_MODE=${APP_MODE}  LOAD_MODE=${LOAD_MODE}"
echo "[up.sh] Artifacts: ${ARTIFACT_ROOT}"

if [[ -n "${RESUME_TARGET:-}" ]]; then
  echo "[up.sh] Resume mode: ${RESUME_TARGET}"
  resume_hpa_proof_run
else
  full_run
fi

# Print scorecard if scorecard.sh is loaded
if declare -f print_final_scorecard >/dev/null 2>&1; then
  print_final_scorecard
fi
