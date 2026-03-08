#!/usr/bin/env bash
# scripts/fix.sh — canonical fix dispatcher for HPA failure codes
# Usage: [ATTEMPT=1] ./scripts/fix.sh HPA-301 | HPA-302 | HPA-303 | HPA-304 | HPA-305 | HPA-306

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
# _fix_start_load <mode>
# Starts load for the given mode.  Host mode always uses --background so fix
# attempts don't block; log goes to FIX_DIR/load-fix.log.
# ---------------------------------------------------------------------------
_fix_start_load() {
  local mode="${1:?_fix_start_load requires mode}"
  if [[ "${mode}" == "host" ]]; then
    ./scripts/load.sh --mode host --preset hpa-proof \
      --background "${FIX_DIR}/load-fix.log"
  else
    ./scripts/load.sh --mode "${mode}" --preset hpa-proof
  fi
}

# ---------------------------------------------------------------------------
# _profile_cpu_request / _profile_mem_request
# Returns the CPU/memory request value for the current PROFILE.
# ---------------------------------------------------------------------------
_profile_cpu_request() {
  case "${PROFILE:-tiny}" in
    tiny)     echo "25m"  ;;
    balanced) echo "50m"  ;;
    stretch)  echo "100m" ;;
    *)        echo "25m"  ;;
  esac
}

_profile_mem_request() {
  case "${PROFILE:-tiny}" in
    tiny)     echo "32Mi"  ;;
    balanced) echo "64Mi"  ;;
    stretch)  echo "128Mi" ;;
    *)        echo "32Mi"  ;;
  esac
}

# ---------------------------------------------------------------------------
# Attempt tracking
# ---------------------------------------------------------------------------
ATTEMPT="${ATTEMPT:-1}"
if [[ "${ATTEMPT}" -lt 1 ]] || [[ "${ATTEMPT}" -gt 3 ]]; then
  echo "[fix.sh] ATTEMPT must be 1, 2, or 3 (got: ${ATTEMPT})" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# log_fix_result <code> <status> <note>
# Writes JSON artifact (with ATTEMPT) and appends to human-readable log.
# ---------------------------------------------------------------------------
log_fix_result() {
  local code="${1:?log_fix_result requires code}"
  local status="${2:?log_fix_result requires status}"
  local note="${3:?log_fix_result requires note}"

  echo "{\"code\":\"${code}\",\"status\":\"${status}\",\"note\":\"${note}\",\"run_id\":\"${RUN_ID:-unknown}\",\"attempt\":${ATTEMPT}}" \
    >> "${FIX_DIR}/${code}.jsonl"

  echo "[$(date -u +%FT%TZ)] code=${code} status=${status} attempt=${ATTEMPT} note=${note}" \
    >> "${FIX_DIR}/${code}.log"
}

# ---------------------------------------------------------------------------
# print_bounded_stop <code>
# Called after all 3 attempts exhausted.
# ---------------------------------------------------------------------------
print_bounded_stop() {
  local code="${1:?}"
  local bundle="${ARTIFACT_ROOT:-artifacts/unset}/fix-escalation-${code}.tar.gz"

  echo "=== Recovery Bounded: ${code} failed after 3 attempts ==="
  echo "Handoff bundle: ${bundle}"
  tar czf "${bundle}" \
    "${FIX_DIR}/${code}"*.log \
    "${FIX_DIR}/${code}"*.jsonl 2>/dev/null || true
  echo "Manual intervention required. See docs/troubleshooting.md#${code}"
  log_fix_result "${code}" "bounded_stop" "3 attempts exhausted"
}

# ===========================================================================
# HPA-301 — HPA resource not found
# ===========================================================================
_fix_301_attempt_1() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  echo "[fix-301] Applying k8s/hpa.yaml..."
  kubectl apply -f k8s/hpa.yaml -n "${ns}"
  echo "[fix-301] Verifying HPA exists..."
  kubectl -n "${ns}" get hpa >/dev/null 2>&1
}

_fix_301_attempt_2() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  echo "[fix-301] Server-side apply k8s/hpa.yaml..."
  kubectl apply --server-side -f k8s/hpa.yaml -n "${ns}"
  echo "[fix-301] Patching scaleTargetRef to ${deploy}..."
  kubectl -n "${ns}" patch hpa "${HPA_NAME:-sample-app-hpa}" \
    --type merge -p "{\"spec\":{\"scaleTargetRef\":{\"name\":\"${deploy}\"}}}" 2>/dev/null || true
  kubectl -n "${ns}" get hpa >/dev/null 2>&1
}

_fix_301_attempt_3() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  echo "[fix-301] Delete + recreate HPA from preset..."
  kubectl -n "${ns}" delete hpa "${HPA_NAME:-sample-app-hpa}" --ignore-not-found
  kubectl apply -f k8s/presets/hpa-proof.yaml -n "${ns}"
  kubectl -n "${ns}" get hpa >/dev/null 2>&1
}

fix_hpa_301() {
  {
    echo "[fix-301] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_301_attempt_1 ;;
      2) _fix_301_attempt_2 ;;
      3) _fix_301_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-301.log" 2>&1 && {
    log_fix_result "HPA-301" "ok" "HPA fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-301" "fail" "HPA fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# HPA-302 — Metrics server unavailable
# ===========================================================================
_fix_302_attempt_1() {
  echo "[fix-302] Applying k8s/addons/metrics-server.yaml..."
  kubectl apply -f k8s/addons/metrics-server.yaml
  echo "[fix-302] Waiting for rollout (timeout 180s)..."
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  echo "[fix-302] Verifying kubectl top nodes..."
  kubectl top nodes >/dev/null 2>&1
}

_fix_302_attempt_2() {
  echo "[fix-302] Restarting metrics-server deployment..."
  kubectl -n kube-system rollout restart deploy/metrics-server
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  # Add --kubelet-insecure-tls if not already present
  local args
  args="$(kubectl -n kube-system get deploy metrics-server \
    -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || echo '[]')"
  if ! echo "${args}" | grep -q 'kubelet-insecure-tls'; then
    echo "[fix-302] Patching --kubelet-insecure-tls arg..."
    kubectl -n kube-system patch deploy metrics-server --type json \
      -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  fi
  kubectl top nodes >/dev/null 2>&1
}

_fix_302_attempt_3() {
  echo "[fix-302] Delete + recreate metrics-server from pinned KinD manifest..."
  kubectl -n kube-system delete deploy metrics-server --ignore-not-found
  kubectl apply -f k8s/addons/metrics-server.yaml
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
  kubectl top nodes >/dev/null 2>&1
}

fix_hpa_302() {
  {
    echo "[fix-302] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_302_attempt_1 ;;
      2) _fix_302_attempt_2 ;;
      3) _fix_302_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-302.log" 2>&1 && {
    log_fix_result "HPA-302" "ok" "metrics-server fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-302" "fail" "metrics-server fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# HPA-303 — CPU requests not set on deployment
# ===========================================================================
_fix_303_attempt_1() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local app_mode="${APP_MODE:-landing}"
  local profile="${PROFILE:-tiny}"
  echo "[fix-303] Applying k8s/app/${app_mode}/deployment-${profile}.yaml..."
  kubectl apply -f "k8s/app/${app_mode}/deployment-${profile}.yaml" -n "${ns}"
  kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s
  kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q .
}

_fix_303_attempt_2() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local container="${APP_CONTAINER:-app}"
  local cpu_req mem_req
  cpu_req="$(_profile_cpu_request)"
  mem_req="$(_profile_mem_request)"
  echo "[fix-303] Patching CPU/memory requests (profile=${PROFILE:-tiny}: cpu=${cpu_req} mem=${mem_req})..."
  kubectl -n "${ns}" patch deploy "${deploy}" --type merge \
    -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${container}\",\"resources\":{\"requests\":{\"cpu\":\"${cpu_req}\",\"memory\":\"${mem_req}\"}}}]}}}}"
  kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s
  kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q .
}

_fix_303_attempt_3() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  echo "[fix-303] Applying tiny-safe fallback deployment preset..."
  kubectl apply -f k8s/presets/deployment-tiny-safe.yaml -n "${ns}"
  kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s
  kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q .
}

fix_hpa_303() {
  {
    echo "[fix-303] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_303_attempt_1 ;;
      2) _fix_303_attempt_2 ;;
      3) _fix_303_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-303.log" 2>&1 && {
    log_fix_result "HPA-303" "ok" "CPU request fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-303" "fail" "CPU request fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# HPA-304 — Load generator failed to start
# ===========================================================================
_fix_304_attempt_1() {
  local load_mode="${LOAD_MODE:-pod}"
  echo "[fix-304] Starting load (mode=${load_mode})..."
  _fix_start_load "${load_mode}"
  ./scripts/load.sh --status | grep -q "active"
}

_fix_304_attempt_2() {
  local load_mode="${LOAD_MODE:-pod}"
  local switched_mode
  if [[ "${load_mode}" == "pod" ]]; then switched_mode="host"; else switched_mode="pod"; fi
  echo "[fix-304] Switching load mode: ${load_mode} → ${switched_mode}..."
  mkdir -p .state
  echo "LOAD_MODE=${switched_mode}" >> .state/env-overrides
  _fix_start_load "${switched_mode}"
  ./scripts/load.sh --status | grep -q "active"
}

_fix_304_attempt_3() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  echo "[fix-304] Starting fallback minimal internal load pod..."
  kubectl -n "${ns}" delete pod load-fallback --ignore-not-found 2>/dev/null || true
  kubectl run load-fallback \
    --image=busybox -n "${ns}" \
    --restart=Never \
    -- /bin/sh -c "while true; do wget -q -O- \"http://${deploy}/\" 2>/dev/null; sleep 1; done"
  kubectl -n "${ns}" get pod load-fallback >/dev/null 2>&1
}

fix_hpa_304() {
  {
    echo "[fix-304] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_304_attempt_1 ;;
      2) _fix_304_attempt_2 ;;
      3) _fix_304_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-304.log" 2>&1 && {
    log_fix_result "HPA-304" "ok" "load generator fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-304" "fail" "load generator fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# HPA-305 — No scale-up observed during ramp window
# ===========================================================================
_fix_305_attempt_1() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local load_mode="${LOAD_MODE:-pod}"
  echo "[fix-305] Applying hpa-proof preset..."
  kubectl apply -f k8s/presets/hpa-proof.yaml -n "${ns}"
  echo "[fix-305] Starting load with hpa-proof preset (mode=${load_mode})..."
  _fix_start_load "${load_mode}"
}

_fix_305_attempt_2() {
  local load_mode="${LOAD_MODE:-pod}"
  echo "[fix-305] Extending ramp window to 300s..."
  mkdir -p .state
  echo "HPA_RAMP_SEC=300" >> .state/env-overrides
  _fix_start_load "${load_mode}"
}

_fix_305_attempt_3() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local hpa="${HPA_NAME:-sample-app-hpa}"
  echo "[fix-305] Lowering HPA CPU target to 20% + switching to host load..."
  kubectl -n "${ns}" patch hpa "${hpa}" --type merge \
    -p '{"spec":{"metrics":[{"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":20}}}]}}'
  mkdir -p .state
  echo "LOAD_MODE=host" >> .state/env-overrides
  echo "HPA_RAMP_SEC=300" >> .state/env-overrides
  _fix_start_load "host"
}

fix_hpa_305() {
  {
    echo "[fix-305] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_305_attempt_1 ;;
      2) _fix_305_attempt_2 ;;
      3) _fix_305_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-305.log" 2>&1 && {
    log_fix_result "HPA-305" "ok" "scale-up fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-305" "fail" "scale-up fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# HPA-306 — Cooldown not observed within window
# ===========================================================================
_fix_306_attempt_1() {
  echo "[fix-306] Stopping load + extending cooldown to 420s..."
  ./scripts/load.sh --stop
  mkdir -p .state
  echo "HPA_COOLDOWN_SEC=420" >> .state/env-overrides
  echo "Cooldown window extended to 420s. Re-run will use this override."
}

_fix_306_attempt_2() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local hpa="${HPA_NAME:-sample-app-hpa}"
  echo "[fix-306] Patching HPA scaleDown stabilizationWindowSeconds=60..."
  kubectl -n "${ns}" patch hpa "${hpa}" --type merge \
    -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":60}}}}'
  mkdir -p .state
  echo "HPA_COOLDOWN_SEC=300" >> .state/env-overrides
  echo "Scale-down stabilization window patched to 60s; cooldown window set to 300s."
}

_fix_306_attempt_3() {
  echo "[fix-306] Enforcing zero-load + 420s observation window..."
  ./scripts/load.sh --stop || true
  mkdir -p .state
  echo "HPA_COOLDOWN_SEC=420" >> .state/env-overrides
  echo "Zero-load enforced; 420s (7-minute) observation window will be used on retry."
}

fix_hpa_306() {
  {
    echo "[fix-306] Attempt ${ATTEMPT}..."
    case "${ATTEMPT}" in
      1) _fix_306_attempt_1 ;;
      2) _fix_306_attempt_2 ;;
      3) _fix_306_attempt_3 ;;
    esac
  } >> "${FIX_DIR}/HPA-306.log" 2>&1 && {
    log_fix_result "HPA-306" "ok" "cooldown fix attempt ${ATTEMPT} succeeded"
  } || {
    log_fix_result "HPA-306" "fail" "cooldown fix attempt ${ATTEMPT} failed"
    return 1
  }
}

# ===========================================================================
# Main dispatch loop — up to 3 attempts
# ===========================================================================
while [[ "${ATTEMPT}" -le 3 ]]; do
  echo "[fix.sh] Attempting ${CODE} (attempt ${ATTEMPT}/3)..."

  fix_rc=0
  case "${CODE}" in
    HPA-301) fix_hpa_301 || fix_rc=$? ;;
    HPA-302) fix_hpa_302 || fix_rc=$? ;;
    HPA-303) fix_hpa_303 || fix_rc=$? ;;
    HPA-304) fix_hpa_304 || fix_rc=$? ;;
    HPA-305) fix_hpa_305 || fix_rc=$? ;;
    HPA-306) fix_hpa_306 || fix_rc=$? ;;
    *)
      echo "Usage: ./scripts/fix.sh HPA-301 | HPA-302 | HPA-303 | HPA-304 | HPA-305 | HPA-306" >&2
      exit 2
      ;;
  esac

  if [[ "${fix_rc}" -eq 0 ]]; then
    break
  fi

  ATTEMPT=$(( ATTEMPT + 1 ))
done

if [[ "${ATTEMPT}" -gt 3 ]]; then
  print_bounded_stop "${CODE}"
  exit 1
fi

print_failure_hint "${NUM}"
echo "Next command: ./scripts/up.sh --resume hpa_proof"
