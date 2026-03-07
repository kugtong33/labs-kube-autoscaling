#!/usr/bin/env bash
# scripts/collect-evidence.sh — standalone evidence capture re-runner
# Usage: ./scripts/collect-evidence.sh [--run-id <id>] [--from-resume]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/gate-evidence.sh"

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
FROM_RESUME=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      export RUN_ID="${2:?--run-id requires a value}"
      shift 2
      ;;
    --from-resume)
      FROM_RESUME=1
      shift
      ;;
    *)
      echo "Usage: ./scripts/collect-evidence.sh [--run-id <id>] [--from-resume]" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve RUN_ID
# ---------------------------------------------------------------------------
if [[ -z "${RUN_ID:-}" ]]; then
  if [[ -f ".state/last_run_id" ]]; then
    export RUN_ID="$(cat .state/last_run_id)"
  else
    echo "[collect-evidence] ERROR: no --run-id given and .state/last_run_id not found." >&2
    echo "[collect-evidence] Run ./scripts/up.sh first, or pass --run-id <id>." >&2
    exit 1
  fi
fi

export ARTIFACT_ROOT="${ARTIFACT_BASE:-artifacts}/${RUN_ID}"
export HPA_DIR="${ARTIFACT_ROOT}/hpa"

echo "[collect-evidence] RUN_ID=${RUN_ID}"
echo "[collect-evidence] ARTIFACT_ROOT=${ARTIFACT_ROOT}"

# ---------------------------------------------------------------------------
# Capture
# ---------------------------------------------------------------------------
gate_evidence_capture || true

echo "[collect-evidence] Evidence collected for run ${RUN_ID}. See ${ARTIFACT_ROOT}/evidence-checklist.md"
exit 0
