#!/usr/bin/env bash
# scripts/lib/gate-bootstrap.sh — bootstrap gate and integrity check
# Source this file; do not execute it directly.

[[ -n "${__GATE_BOOTSTRAP_SH:-}" ]] && return
__GATE_BOOTSTRAP_SH=1

# ---------------------------------------------------------------------------
# gate_bootstrap
#
# Full idempotent provisioning:
#   1. KinD cluster (create if absent)
#   2. Namespace (idempotent apply)
#   3. metrics-server (apply + rollout wait)
#   4. App deployment + HPA (via apply_app_mode from E8)
#   5. Deployment readiness wait
#   6. Print NodePort URL
#
# Returns non-zero on any unrecoverable step.
# ---------------------------------------------------------------------------
gate_bootstrap() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"

  # ------------------------------------------------------------------
  # 1. KinD cluster — idempotent
  # ------------------------------------------------------------------
  echo "[bootstrap] Checking KinD cluster..."
  local cluster="${CLUSTER_NAME:-autoscaling-lab}"
  local kind_config="k8s/kind-config.yaml"
  if kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "[bootstrap] Cluster '${cluster}' already exists — skipping create."
  else
    echo "[bootstrap] Creating KinD cluster '${cluster}'..."
    if ! kind create cluster --name "${cluster}" --config "${kind_config}"; then
      echo "[bootstrap] Cluster creation failed. Cleaning up and retrying..."
      kind delete cluster --name "${cluster}" 2>/dev/null || true
      docker rm -f "${cluster}-control-plane" 2>/dev/null || true
      echo "[bootstrap] Retrying cluster creation..."
      if ! kind create cluster --name "${cluster}" --config "${kind_config}"; then
        echo "[bootstrap] ERROR: Cluster creation failed after retry. Aborting." >&2
        return 1
      fi
    fi
  fi

  # Apply profile-based Docker memory limit to the cluster node (best-effort)
  local node_mem
  case "${PROFILE:-tiny}" in
    tiny)     node_mem="2g" ;;
    balanced) node_mem="4g" ;;
    stretch)  node_mem="8g" ;;
    *)        node_mem="2g" ;;
  esac
  echo "[bootstrap] Applying ${node_mem} memory limit to node '${cluster}-control-plane'..."
  docker update --memory "${node_mem}" --memory-swap "${node_mem}" \
    "${cluster}-control-plane" 2>/dev/null \
    && echo "[bootstrap] Node memory limit set: ${node_mem}" \
    || echo "[bootstrap] WARN: docker update memory limit not supported in this environment (continuing)"

  # Explicitly switch to the correct kubectl context before any resource ops
  ensure_cluster_context

  echo "[bootstrap] Verifying cluster reachability..."
  kubectl cluster-info --context "kind-${cluster}"

  # ------------------------------------------------------------------
  # 2. Namespace — idempotent
  # ------------------------------------------------------------------
  echo "[bootstrap] Ensuring namespace '${ns}'..."
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl get ns "${ns}" >/dev/null

  # ------------------------------------------------------------------
  # 3. metrics-server
  # ------------------------------------------------------------------
  echo "[bootstrap] Applying metrics-server..."
  kubectl apply -f k8s/addons/metrics-server.yaml

  echo "[bootstrap] Waiting for metrics-server rollout (timeout 180s)..."
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

  echo "[bootstrap] Verifying kubectl top nodes..."
  local attempts=0
  until kubectl top nodes >/dev/null 2>&1 || [[ "${attempts}" -ge 12 ]]; do
    echo "[bootstrap] Waiting for metrics API to become available... (${attempts}/12)"
    sleep 10
    attempts=$(( attempts + 1 ))
  done
  kubectl top nodes >/dev/null

  # ------------------------------------------------------------------
  # 4. App deployment + HPA (delegated to apply_app_mode from E8)
  # ------------------------------------------------------------------
  echo "[bootstrap] Applying app mode: APP_MODE=${APP_MODE:-landing} PROFILE=${PROFILE:-tiny}..."
  if declare -f apply_app_mode >/dev/null 2>&1; then
    apply_app_mode
  else
    echo "[bootstrap] WARNING: apply_app_mode not available (app-mode.sh not loaded)." >&2
    echo "[bootstrap] Falling back to direct manifest apply..."
    local app_mode="${APP_MODE:-landing}"
    local profile="${PROFILE:-tiny}"
    kubectl apply -f "k8s/app/${app_mode}/deployment-${profile}.yaml" -n "${ns}"
    kubectl apply -f "k8s/app/${app_mode}/service.yaml"    -n "${ns}"
    kubectl apply -f "k8s/hpa-${profile}.yaml"             -n "${ns}"
  fi

  # ------------------------------------------------------------------
  # 5. Deployment readiness wait
  # ------------------------------------------------------------------
  echo "[bootstrap] Waiting for deployment '${deploy}' rollout (timeout 180s)..."
  kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s

  # ------------------------------------------------------------------
  # 6. Print NodePort URL
  # ------------------------------------------------------------------
  local node_port
  node_port="$(kubectl get svc -n "${ns}" "${deploy}" \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"

  echo "[bootstrap] Bootstrap complete."
  kubectl cluster-info --context "kind-${cluster}"

  if [[ -n "${node_port}" ]]; then
    echo "[bootstrap] NodePort URL: http://localhost:${node_port}"
  fi
}

# ---------------------------------------------------------------------------
# gate_bootstrap_integrity
#
# Read-only health check used by the resume sequence.
# Does NOT create, apply, or modify any resource.
# Returns non-zero on any failing check.
# ---------------------------------------------------------------------------
gate_bootstrap_integrity() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local hpa="${HPA_NAME:-sample-app-hpa}"
  local cluster="${CLUSTER_NAME:-autoscaling-lab}"
  local ok=1

  # Switch to the correct context before any kubectl calls
  if ! ensure_cluster_context; then
    echo "[bootstrap-integrity] FAIL: cannot select cluster context." >&2
    return 1
  fi

  echo "[bootstrap-integrity] Checking KinD cluster..."
  if kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "[bootstrap-integrity] Cluster: OK"
  else
    echo "[bootstrap-integrity] FAIL: cluster '${cluster}' not found." >&2
    ok=0
  fi

  echo "[bootstrap-integrity] Checking namespace '${ns}'..."
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    echo "[bootstrap-integrity] Namespace: OK"
  else
    echo "[bootstrap-integrity] FAIL: namespace '${ns}' not found." >&2
    ok=0
  fi

  echo "[bootstrap-integrity] Checking deployment '${deploy}'..."
  if kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=30s >/dev/null 2>&1; then
    echo "[bootstrap-integrity] Deployment: OK"
  else
    echo "[bootstrap-integrity] FAIL: deployment '${deploy}' not healthy." >&2
    ok=0
  fi

  echo "[bootstrap-integrity] Checking HPA '${hpa}'..."
  if kubectl -n "${ns}" get hpa "${hpa}" >/dev/null 2>&1; then
    echo "[bootstrap-integrity] HPA: OK"
  else
    echo "[bootstrap-integrity] FAIL: HPA '${hpa}' not found in namespace '${ns}'." >&2
    ok=0
  fi

  if [[ "${ok}" -eq 1 ]]; then
    echo "[bootstrap-integrity] Bootstrap integrity: OK"
    return 0
  else
    return 1
  fi
}
