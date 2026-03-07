#!/usr/bin/env bash
# scripts/lib/gate-reachability.sh — reachability gate
# Confirms the app is HTTP-accessible via NodePort before load testing begins.
# Source this file; do not execute it directly.

[[ -n "${__GATE_REACHABILITY_SH:-}" ]] && return
__GATE_REACHABILITY_SH=1

# ---------------------------------------------------------------------------
# gate_reachability
#
# 1. Detects NodePort for the service
# 2. Smoke-checks http://localhost:<nodeport>/ with curl (3 attempts, 5s backoff)
# 3. Prints Lab URL on success
#
# Returns non-zero if NodePort is missing or all curl attempts fail.
# ---------------------------------------------------------------------------
gate_reachability() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local svc="${APP_DEPLOYMENT:-sample-app}"

  # ------------------------------------------------------------------
  # NodePort detection
  # ------------------------------------------------------------------
  echo "[reachability] Detecting NodePort for service '${svc}' in namespace '${ns}'..."
  local node_port
  node_port="$(kubectl get svc -n "${ns}" "${svc}" \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"

  if [[ -z "${node_port}" ]]; then
    echo "[reachability] FAIL: NodePort not found for service '${svc}'." >&2
    echo "[reachability] Check: kubectl get svc -n ${ns} ${svc}" >&2
    return 1
  fi

  echo "[reachability] NodePort: ${node_port}"

  # ------------------------------------------------------------------
  # curl smoke check with retry
  # ------------------------------------------------------------------
  local attempt=1
  local max_attempts=3
  local backoff=5
  local url="http://localhost:${node_port}/"

  while [[ "${attempt}" -le "${max_attempts}" ]]; do
    echo "[reachability] Attempt ${attempt}/${max_attempts}: GET ${url}"
    if curl -sf --max-time 5 "${url}" >/dev/null 2>&1; then
      echo "[reachability] HTTP check passed."
      echo ""
      echo "Lab URL: http://localhost:${node_port}"
      return 0
    fi

    if [[ "${attempt}" -lt "${max_attempts}" ]]; then
      echo "[reachability] No response — retrying in ${backoff}s..."
      sleep "${backoff}"
    fi
    attempt=$(( attempt + 1 ))
  done

  echo "[reachability] FAIL: service at ${url} did not respond after ${max_attempts} attempts." >&2
  echo "[reachability] Check: kubectl -n ${ns} get pods" >&2
  return 1
}
