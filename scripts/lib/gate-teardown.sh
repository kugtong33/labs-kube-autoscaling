#!/usr/bin/env bash
# scripts/lib/gate-teardown.sh — teardown helpers and integrity gate
# Source this file; do not execute it directly.

[[ -n "${__GATE_TEARDOWN_SH:-}" ]] && return
__GATE_TEARDOWN_SH=1

# ---------------------------------------------------------------------------
# teardown_namespace
#
# Stops load, deletes the namespace, optionally clears .state/ files.
# Always returns 0 (|| true on kubectl to survive already-absent namespace).
# ---------------------------------------------------------------------------
teardown_namespace() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local preserve="${PRESERVE_ARTIFACTS:-0}"

  echo "[teardown] Stopping any running load generator..."
  ./scripts/load.sh --stop 2>/dev/null || true

  echo "[teardown] Deleting namespace ${ns}..."
  kubectl delete ns "${ns}" --timeout=60s 2>/dev/null || true

  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    echo "[teardown] Warning: namespace still exists"
  else
    echo "[teardown] Namespace deleted: ${ns}"
  fi

  if [[ "${preserve}" -eq 0 ]]; then
    echo "[teardown] Clearing .state/ files..."
    rm -f .state/last_run_id .state/load.pid .state/env-overrides
  fi

  echo "[teardown] Namespace teardown: done"
}

# ---------------------------------------------------------------------------
# teardown_cluster
#
# Deletes the KinD cluster if it exists.
# ---------------------------------------------------------------------------
teardown_cluster() {
  local cluster="${CLUSTER_NAME:-autoscaling-lab}"
  if ! kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "[teardown] Cluster '${cluster}' not found — skipping."
    return 0
  fi

  echo "[teardown] Deleting KinD cluster ${cluster}..."
  kind delete cluster --name "${cluster}"

  if kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "[teardown] Warning: cluster still listed"
  else
    echo "[teardown] Cluster deleted"
  fi

  echo "[teardown] Cluster teardown: done"
}

# ---------------------------------------------------------------------------
# gate_teardown_integrity
#
# NON_CRITICAL: verifies teardown state and writes teardown-integrity.json.
# Always returns 0 — result is informational only.
# ---------------------------------------------------------------------------
gate_teardown_integrity() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local artifact_root="${ARTIFACT_ROOT:-artifacts/unset}"

  mkdir -p "${artifact_root}"

  # Check namespace deletion
  local namespace_deleted="false"
  if ! kubectl get ns "${ns}" 2>/dev/null; then
    namespace_deleted="true"
    echo "[teardown-integrity] Namespace '${ns}': deleted ✓"
  else
    echo "[teardown-integrity] Namespace '${ns}': still present"
  fi

  # Check cluster status
  local cluster_status="deleted"
  if kubectl cluster-info --context "kind-${CLUSTER_NAME:-autoscaling-lab}" >/dev/null 2>&1; then
    cluster_status="present"
    echo "[teardown-integrity] Cluster: present"
  else
    echo "[teardown-integrity] Cluster: deleted or unreachable"
  fi

  # Determine re-run readiness:
  # Ready if namespace is gone (fresh bootstrap won't conflict) regardless of cluster state
  local rerun_ready="false"
  if [[ "${namespace_deleted}" == "true" ]]; then
    rerun_ready="true"
  fi

  echo "[teardown-integrity] Re-run ready: ${rerun_ready}"

  # Write JSON artifact
  cat > "${artifact_root}/teardown-integrity.json" <<EOF
{"namespace_deleted":${namespace_deleted},"cluster_status":"${cluster_status}","rerun_ready":${rerun_ready}}
EOF

  echo "[teardown-integrity] Written: ${artifact_root}/teardown-integrity.json"
  return 0
}
