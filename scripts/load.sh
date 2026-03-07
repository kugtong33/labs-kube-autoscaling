#!/usr/bin/env bash
# scripts/load.sh — load generator for autoscaling lab
# Usage: ./scripts/load.sh --mode pod|host [--preset hpa-proof] [--concurrency <n>]
#        ./scripts/load.sh --status
#        ./scripts/load.sh --stop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

mkdir -p .state

# ---------------------------------------------------------------------------
# apply_preset <name>
# Sets LOAD_CONCURRENCY and LOAD_SLEEP_SEC for a named preset.
# ---------------------------------------------------------------------------
apply_preset() {
  local preset="${1:?apply_preset requires preset name}"
  case "${preset}" in
    hpa-proof)
      # Low enough to avoid overwhelming the tiny node;
      # high enough to trigger HPA at averageUtilization=50
      export LOAD_CONCURRENCY=5
      export LOAD_SLEEP_SEC=0.5
      echo "[load] Preset applied: hpa-proof (concurrency=5, sleep=0.5s)"
      ;;
    *)
      echo "[load] Unknown preset '${preset}'" >&2
      exit 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# start_load_pod
# Runs a busybox curl-loop pod in the namespace, labeled for cleanup.
# ---------------------------------------------------------------------------
start_load_pod() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local sleep_sec="${LOAD_SLEEP_SEC:-0.1}"
  local url="http://${deploy}/"

  echo "[load] Deleting any existing load-generator pod..."
  kubectl delete pod load-generator -n "${ns}" --ignore-not-found >/dev/null 2>&1 || true

  echo "[load] Starting load-generator pod (mode=pod, sleep=${sleep_sec}s)..."
  kubectl run load-generator \
    -n "${ns}" \
    --image=busybox \
    --restart=Never \
    --labels="app=load-generator,managed-by=load-sh" \
    -- /bin/sh -c "while true; do wget -q -O- ${url}; sleep ${sleep_sec}; done"

  echo "[load] Waiting for pod to be running (timeout 30s)..."
  kubectl -n "${ns}" wait pod/load-generator --for=condition=Ready --timeout=30s 2>/dev/null || true
  kubectl -n "${ns}" get pod load-generator

  echo "[load] Load generator started (mode=pod)"
}

# ---------------------------------------------------------------------------
# start_load_host
# Starts a background curl loop on the host; tracks PID in .state/load.pid.
# ---------------------------------------------------------------------------
start_load_host() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local sleep_sec="${LOAD_SLEEP_SEC:-0.1}"

  echo "[load] Detecting NodePort..."
  local node_port
  node_port="$(kubectl get svc -n "${ns}" "${deploy}" \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"

  if [[ -z "${node_port}" ]]; then
    echo "[load] ERROR: NodePort not found for service '${deploy}'" >&2
    return 1
  fi

  local url="http://localhost:${node_port}/"
  echo "[load] Starting host curl loop → ${url} (sleep=${sleep_sec}s)..."

  # Stop any existing host load first
  stop_load_host 2>/dev/null || true

  while true; do curl -sf --max-time 2 "${url}" >/dev/null 2>&1; sleep "${sleep_sec}"; done &
  local load_pid=$!
  echo "${load_pid}" > .state/load.pid

  echo "[load] Load generator started (mode=host, pid=${load_pid})"
}

# ---------------------------------------------------------------------------
# stop_load_pod
# Deletes load-generator pods by label.
# ---------------------------------------------------------------------------
stop_load_pod() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  echo "[load] Deleting load-generator pods (label: app=load-generator)..."
  kubectl delete pods -n "${ns}" -l app=load-generator --ignore-not-found >/dev/null 2>&1 || true
  echo "[load] Load generator stopped (mode=pod)"
}

# ---------------------------------------------------------------------------
# stop_load_host
# Reads and kills the PID stored in .state/load.pid.
# ---------------------------------------------------------------------------
stop_load_host() {
  if [[ ! -f .state/load.pid ]]; then
    echo "[load] No host load PID found"
    return 0
  fi
  local load_pid
  load_pid="$(cat .state/load.pid)"
  kill "${load_pid}" 2>/dev/null || true
  rm -f .state/load.pid
  echo "[load] Load generator stopped (mode=host, pid=${load_pid})"
}

# ---------------------------------------------------------------------------
# stop_load
# Stops both pod and host load (idempotent).
# ---------------------------------------------------------------------------
stop_load() {
  stop_load_pod
  stop_load_host
}

# ---------------------------------------------------------------------------
# status_load
# Prints "active (mode=pod|host)" or "stopped".
# ---------------------------------------------------------------------------
status_load() {
  local ns="${NAMESPACE:-autoscaling-lab}"

  # Check pod mode
  local phase
  phase="$(kubectl -n "${ns}" get pod load-generator \
    --ignore-not-found \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "${phase}" == "Running" ]]; then
    echo "active (mode=pod)"
    return 0
  fi

  # Check host mode
  if [[ -f .state/load.pid ]]; then
    local pid
    pid="$(cat .state/load.pid)"
    if kill -0 "${pid}" 2>/dev/null; then
      echo "active (mode=host)"
      return 0
    fi
  fi

  echo "stopped"
  return 0
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
MODE=""
PRESET=""
CONCURRENCY="${LOAD_CONCURRENCY:-10}"
DO_STATUS=0
DO_STOP=0

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/load.sh --mode pod|host [--preset hpa-proof] [--concurrency <n>]" >&2
  echo "       ./scripts/load.sh --status" >&2
  echo "       ./scripts/load.sh --stop" >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?--mode requires a value (pod|host)}"
      case "${MODE}" in
        pod|host) ;;
        *) echo "[load] Invalid --mode '${MODE}'. Valid: pod, host" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    --preset)
      PRESET="${2:?--preset requires a value}"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="${2:?--concurrency requires a value}"
      shift 2
      ;;
    --status)
      DO_STATUS=1
      shift
      ;;
    --stop)
      DO_STOP=1
      shift
      ;;
    *)
      echo "[load] Unknown argument: $1" >&2
      echo "Usage: ./scripts/load.sh --mode pod|host [--preset hpa-proof] [--concurrency <n>]" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
if [[ "${DO_STATUS}" -eq 1 ]]; then
  status_load
  exit 0
fi

if [[ "${DO_STOP}" -eq 1 ]]; then
  stop_load
  exit 0
fi

if [[ -n "${PRESET}" ]]; then
  apply_preset "${PRESET}"
fi

export LOAD_CONCURRENCY="${CONCURRENCY}"

case "${MODE}" in
  pod)  start_load_pod ;;
  host) start_load_host ;;
  *)
    echo "[load] No --mode specified." >&2
    echo "Usage: ./scripts/load.sh --mode pod|host [--preset hpa-proof] [--concurrency <n>]" >&2
    exit 2
    ;;
esac
