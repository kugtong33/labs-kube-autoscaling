#!/usr/bin/env bash
# scripts/down.sh — autoscaling lab teardown
# Usage: ./scripts/down.sh [--run-id <id>] [--preserve-artifacts] [--delete-cluster]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/gate-teardown.sh"

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
PRESERVE_ARTIFACTS=0
DELETE_CLUSTER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      export RUN_ID="${2:?--run-id requires a value}"
      shift 2
      ;;
    --preserve-artifacts)
      PRESERVE_ARTIFACTS=1
      shift
      ;;
    --delete-cluster)
      DELETE_CLUSTER=1
      shift
      ;;
    --help|-h)
      echo "Usage: ./scripts/down.sh [--run-id <id>] [--preserve-artifacts] [--delete-cluster]"
      exit 0
      ;;
    *)
      echo "[down.sh] Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

export PRESERVE_ARTIFACTS
export DELETE_CLUSTER

# Resolve ARTIFACT_ROOT for teardown-integrity.json
if [[ -z "${RUN_ID:-}" ]] && [[ -f ".state/last_run_id" ]]; then
  export RUN_ID="$(cat .state/last_run_id)"
fi
export ARTIFACT_ROOT="${ARTIFACT_BASE:-artifacts}/${RUN_ID:-unset}"

echo "[down.sh] NAMESPACE=${NAMESPACE}"
echo "[down.sh] DELETE_CLUSTER=${DELETE_CLUSTER}  PRESERVE_ARTIFACTS=${PRESERVE_ARTIFACTS}"

# Switch to the correct cluster context before any kubectl operations.
# Use || true: if the cluster was already deleted, teardown can still clean up.
ensure_cluster_context || true

# ---------------------------------------------------------------------------
# Teardown sequence
# ---------------------------------------------------------------------------
teardown_namespace

if [[ "${DELETE_CLUSTER}" -eq 1 ]]; then
  teardown_cluster
fi

gate_teardown_integrity || true

echo ""
echo "Teardown complete. Re-run: ./scripts/up.sh"
