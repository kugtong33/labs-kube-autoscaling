#!/usr/bin/env bash
# scripts/fix.sh — canonical fix dispatcher for HPA failure codes
# Usage: ./scripts/fix.sh HPA-301 | HPA-302 | HPA-303 | HPA-304 | HPA-305 | HPA-306

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/failure-maps.sh"

# Resolve artifact dirs (RUN_ID may not be set when fix.sh is called standalone)
FIX_DIR="${FIX_DIR:-artifacts/${RUN_ID:-unset}/fix}"
mkdir -p "${FIX_DIR}"

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
CODE="${1:-}"

if [[ -z "${CODE}" ]] || [[ ! "${CODE}" =~ ^HPA-30[1-6]$ ]]; then
  echo "Usage: ./scripts/fix.sh HPA-301 | HPA-302 | HPA-303 | HPA-304 | HPA-305 | HPA-306" >&2
  exit 2
fi

NUM="${CODE#HPA-}"

# ---------------------------------------------------------------------------
# log_fix_result <code> <status> <note>
# Writes JSON artifact and appends to human-readable log.
# ---------------------------------------------------------------------------
log_fix_result() {
  local code="${1:?log_fix_result requires code}"
  local status="${2:?log_fix_result requires status}"
  local note="${3:?log_fix_result requires note}"

  cat > "${FIX_DIR}/${code}.json" <<EOF
{"code":"${code}","status":"${status}","note":"${note}","run_id":"${RUN_ID:-unknown}"}
EOF

  echo "[$(date -u +%FT%TZ)] code=${code} status=${status} note=${note}" \
    >> "${FIX_DIR}/${code}.log"
}

# ---------------------------------------------------------------------------
# fix_hpa_301 — HPA resource not found
# Apply k8s/hpa.yaml and verify HPA exists.
# ---------------------------------------------------------------------------
fix_hpa_301() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  {
    echo "[fix-301] Applying k8s/hpa.yaml..."
    kubectl apply -f k8s/hpa.yaml -n "${ns}"

    echo "[fix-301] Verifying HPA exists..."
    kubectl -n "${ns}" get hpa >/dev/null 2>&1
  } >> "${FIX_DIR}/HPA-301.log" 2>&1 && {
    log_fix_result "HPA-301" "ok" "HPA applied from k8s/hpa.yaml"
  } || {
    log_fix_result "HPA-301" "fail" "kubectl apply returned non-zero"
    return 1
  }
}

# ---------------------------------------------------------------------------
# fix_hpa_302 — Metrics server unavailable
# Apply metrics-server.yaml, wait for rollout, verify kubectl top nodes.
# ---------------------------------------------------------------------------
fix_hpa_302() {
  {
    echo "[fix-302] Applying k8s/addons/metrics-server.yaml..."
    kubectl apply -f k8s/addons/metrics-server.yaml

    echo "[fix-302] Waiting for metrics-server rollout (timeout 180s)..."
    kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

    echo "[fix-302] Verifying kubectl top nodes..."
    kubectl top nodes >/dev/null 2>&1
  } >> "${FIX_DIR}/HPA-302.log" 2>&1 && {
    log_fix_result "HPA-302" "ok" "metrics-server applied and rolled out"
  } || {
    log_fix_result "HPA-302" "fail" "metrics-server rollout or top nodes failed"
    return 1
  }
}

# ---------------------------------------------------------------------------
# fix_hpa_303 — CPU requests not set on deployment
# Re-apply deployment.yaml, wait for rollout, verify CPU request.
# ---------------------------------------------------------------------------
fix_hpa_303() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local app_mode="${APP_MODE:-landing}"
  {
    echo "[fix-303] Applying k8s/app/${app_mode}/deployment.yaml..."
    kubectl apply -f "k8s/app/${app_mode}/deployment.yaml" -n "${ns}"

    echo "[fix-303] Waiting for rollout (timeout 180s)..."
    kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s

    echo "[fix-303] Verifying CPU request is set..."
    kubectl -n "${ns}" get deploy "${deploy}" \
      -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' \
      | grep -q .
  } >> "${FIX_DIR}/HPA-303.log" 2>&1 && {
    log_fix_result "HPA-303" "ok" "deployment reapplied with CPU requests"
  } || {
    log_fix_result "HPA-303" "fail" "CPU request still missing after apply"
    return 1
  }
}

# ---------------------------------------------------------------------------
# fix_hpa_304 — Load generator failed to start
# Start load and verify --status reports active.
# ---------------------------------------------------------------------------
fix_hpa_304() {
  local load_mode="${LOAD_MODE:-pod}"
  {
    echo "[fix-304] Starting load (mode=${load_mode})..."
    ./scripts/load.sh --mode "${load_mode}"

    echo "[fix-304] Verifying load is active..."
    ./scripts/load.sh --status | grep -q "active"
  } >> "${FIX_DIR}/HPA-304.log" 2>&1 && {
    log_fix_result "HPA-304" "ok" "load generator started (mode=${load_mode})"
  } || {
    log_fix_result "HPA-304" "fail" "load generator not active after start attempt"
    return 1
  }
}

# ---------------------------------------------------------------------------
# fix_hpa_305 — No scale-up observed during ramp window
# Apply hpa-proof preset and start load with preset.
# ---------------------------------------------------------------------------
fix_hpa_305() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local load_mode="${LOAD_MODE:-pod}"
  {
    echo "[fix-305] Applying k8s/presets/hpa-proof.yaml..."
    kubectl apply -f k8s/presets/hpa-proof.yaml -n "${ns}"

    echo "[fix-305] Starting load with hpa-proof preset (mode=${load_mode})..."
    ./scripts/load.sh --preset hpa-proof --mode "${load_mode}"
  } >> "${FIX_DIR}/HPA-305.log" 2>&1 && {
    log_fix_result "HPA-305" "ok" "hpa-proof preset applied and load started"
  } || {
    log_fix_result "HPA-305" "fail" "preset apply or load start failed"
    return 1
  }
}

# ---------------------------------------------------------------------------
# fix_hpa_306 — Cooldown not observed within window
# Stop load and write HPA_COOLDOWN_SEC=420 env override.
# ---------------------------------------------------------------------------
fix_hpa_306() {
  {
    echo "[fix-306] Stopping load..."
    ./scripts/load.sh --stop

    echo "[fix-306] Writing HPA_COOLDOWN_SEC=420 env override..."
    mkdir -p .state
    echo "HPA_COOLDOWN_SEC=420" >> .state/env-overrides
    echo "Cooldown window extended to 420s. Re-run will use this override."
  } >> "${FIX_DIR}/HPA-306.log" 2>&1 && {
    log_fix_result "HPA-306" "ok" "load stopped; HPA_COOLDOWN_SEC=420 override written"
  } || {
    log_fix_result "HPA-306" "fail" "load stop or override write failed"
    return 1
  }
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "${CODE}" in
  HPA-301) fix_hpa_301 ;;
  HPA-302) fix_hpa_302 ;;
  HPA-303) fix_hpa_303 ;;
  HPA-304) fix_hpa_304 ;;
  HPA-305) fix_hpa_305 ;;
  HPA-306) fix_hpa_306 ;;
  *)
    echo "Usage: ./scripts/fix.sh HPA-301 | HPA-302 | HPA-303 | HPA-304 | HPA-305 | HPA-306" >&2
    exit 2
    ;;
esac

print_failure_hint "${NUM}"
echo "Next command: ./scripts/up.sh --resume hpa_proof"
