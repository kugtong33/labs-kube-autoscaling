#!/usr/bin/env bash
# scripts/load.sh — load generator for autoscaling lab
#
# Host mode defaults to foreground (fibonacci concurrency ramp, live progress).
# Use --background <logfile> to run detached and write progress to a file.
#
# Usage:
#   ./scripts/load.sh --mode host [--preset hpa-proof]                      # foreground
#   ./scripts/load.sh --mode host [--preset hpa-proof] --background <file>  # background
#   ./scripts/load.sh --mode pod  [--preset hpa-proof] [--concurrency <n>]  # in-cluster pod
#   ./scripts/load.sh --status
#   ./scripts/load.sh --stop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

# ---------------------------------------------------------------------------
# apply_preset <name>
# ---------------------------------------------------------------------------
apply_preset() {
  local preset="${1:?apply_preset requires preset name}"
  case "${preset}" in
    hpa-proof)
      export LOAD_SLEEP_SEC=0
      export LOAD_CONCURRENCY=20   # used by pod mode only; host mode uses fibonacci
      echo "[load] Preset applied: hpa-proof (pod concurrency=20, sleep=0s)"
      ;;
    *)
      echo "[load] Unknown preset '${preset}'" >&2
      exit 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# _run_host_load <url> [logfile]
#
# Core load loop for host mode.  Each batch fires CONCURRENCY curl requests
# in parallel (background subshells + wait).  Concurrency follows the
# Fibonacci sequence (3, 5, 8, 13, 21, …), stepping up every 10 seconds.
#
# logfile empty  → foreground: \r progress on terminal, Ctrl+C prints summary.
# logfile set    → background: timestamped lines appended to logfile.
# ---------------------------------------------------------------------------
_run_host_load() {
  local url="$1"
  local logfile="${2:-}"

  local fib_a=3 fib_b=5
  local concurrency=3
  local last_step_ts
  last_step_ts=$(date +%s)

  local total=0 total_ms=0
  local _batch_dir=""

  _rhl_cleanup() {
    [[ -n "${_batch_dir}" ]] && rm -rf "${_batch_dir}" 2>/dev/null || true
  }

  if [[ -z "${logfile}" ]]; then
    trap '_rhl_cleanup; printf "\n"; echo "[load] Stopped. requests=${total} avg_latency=$(( total > 0 ? total_ms / total : 0 ))ms concurrency=${concurrency}"; exit 0' INT TERM
    echo "[load] Fibonacci concurrency ramp: 3 → 5 → 8 → 13 → 21 → … (step every 10s)"
    echo "[load] Press Ctrl+C to stop."
  else
    trap '_rhl_cleanup' EXIT
    {
      echo "[load] Background load started → ${url}"
      echo "[load] Fibonacci concurrency ramp: 3, 5, 8, 13, 21, … (step every 10s)"
    } >> "${logfile}"
  fi

  while true; do
    # --- fibonacci step ---
    local now
    now=$(date +%s)
    if (( now - last_step_ts >= 10 )); then
      local prev=${concurrency}
      local next=$(( fib_a + fib_b ))
      fib_a=${fib_b}
      fib_b=${next}
      concurrency=${fib_a}
      last_step_ts=${now}

      if [[ -z "${logfile}" ]]; then
        printf "\n[load] Concurrency stepped: %d → %d\n" "${prev}" "${concurrency}"
      else
        echo "[load] Concurrency stepped: ${prev} → ${concurrency}" >> "${logfile}"
      fi
    fi

    # --- fire CONCURRENCY requests in parallel ---
    _batch_dir="$(mktemp -d)"
    local pids=()
    for i in $(seq 1 "${concurrency}"); do
      (
        local t_start t_end
        t_start=$(date +%s%3N)
        curl -sf --max-time 2 "${url}" >/dev/null 2>&1 || true
        t_end=$(date +%s%3N)
        echo $(( t_end - t_start )) > "${_batch_dir}/${i}"
      ) &
      pids+=($!)
    done
    wait "${pids[@]}" 2>/dev/null || true

    # --- collect timing from completed workers ---
    for f in "${_batch_dir}"/*; do
      [[ -f "${f}" ]] || continue
      local ms
      ms=$(cat "${f}" 2>/dev/null || echo 0)
      total=$(( total + 1 ))
      total_ms=$(( total_ms + ms ))
    done
    rm -rf "${_batch_dir}"
    _batch_dir=""

    local avg=$(( total > 0 ? total_ms / total : 0 ))
    if [[ -z "${logfile}" ]]; then
      printf "\r[load] requests=%-6d  avg_latency=%3dms  concurrency=%2d" \
        "${total}" "${avg}" "${concurrency}"
    else
      echo "[load] requests=${total} avg_latency=${avg}ms concurrency=${concurrency}" \
        >> "${logfile}"
    fi
  done
}

# ---------------------------------------------------------------------------
# start_load_pod
# Runs a busybox pod with LOAD_CONCURRENCY parallel wget workers per batch.
# Pod mode is always in-cluster (background by nature).
# ---------------------------------------------------------------------------
start_load_pod() {
  ensure_cluster_context || return 1
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local sleep_sec="${LOAD_SLEEP_SEC:-0.1}"
  local concurrency="${LOAD_CONCURRENCY:-10}"
  local url="http://${deploy}/"

  # Validate before embedding in pod shell command
  if [[ ! "${concurrency}" =~ ^[0-9]+$ ]] || [[ "${concurrency}" -lt 1 ]]; then
    echo "[load] ERROR: Invalid LOAD_CONCURRENCY='${concurrency}'. Must be a positive integer." >&2
    return 1
  fi
  if [[ ! "${sleep_sec}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "[load] ERROR: Invalid LOAD_SLEEP_SEC='${sleep_sec}'. Must be a non-negative number." >&2
    return 1
  fi

  echo "[load] Deleting any existing load-generator pod..."
  kubectl delete pod load-generator -n "${ns}" --ignore-not-found >/dev/null 2>&1 || true

  echo "[load] Starting load-generator pod (concurrency=${concurrency}, sleep=${sleep_sec}s)..."
  kubectl run load-generator \
    -n "${ns}" \
    --image=busybox \
    --restart=Never \
    --labels="app=load-generator,managed-by=load-sh" \
    --env="LOAD_CONCURRENCY=${concurrency}" \
    --env="LOAD_SLEEP_SEC=${sleep_sec}" \
    --env="LOAD_URL=${url}" \
    -- /bin/sh -c 'while true; do
      for i in $(seq 1 "$LOAD_CONCURRENCY"); do
        wget -q -O- "$LOAD_URL" &
      done
      wait
      sleep "$LOAD_SLEEP_SEC"
    done'

  echo "[load] Waiting for pod to be running (timeout 30s)..."
  kubectl -n "${ns}" wait pod/load-generator --for=condition=Ready --timeout=30s 2>/dev/null || true
  kubectl -n "${ns}" get pod load-generator

  echo "[load] Load generator started (mode=pod)"
}

# ---------------------------------------------------------------------------
# start_load_host
# Foreground by default.  Pass BACKGROUND_LOG=<file> to run detached.
# ---------------------------------------------------------------------------
start_load_host() {
  ensure_cluster_context || return 1
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local logfile="${BACKGROUND_LOG:-}"

  echo "[load] Detecting NodePort..."
  local node_port
  node_port="$(kubectl get svc -n "${ns}" "${deploy}" \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"

  if [[ -z "${node_port}" ]]; then
    echo "[load] ERROR: NodePort not found for service '${deploy}'" >&2
    return 1
  fi

  local url="http://localhost:${node_port}/"
  stop_load_host 2>/dev/null || true
  mkdir -p .state

  if [[ -n "${logfile}" ]]; then
    echo "[load] Starting background load → ${url}  (log: ${logfile})"
    _run_host_load "${url}" "${logfile}" &
    echo "$!" > .state/load.pids
    echo "[load] Load generator running in background (pid=$(cat .state/load.pids))"
  else
    echo "[load] Starting foreground load → ${url}"
    _run_host_load "${url}"
  fi
}

# ---------------------------------------------------------------------------
# stop_load_pod
# ---------------------------------------------------------------------------
stop_load_pod() {
  ensure_cluster_context 2>/dev/null || true
  local ns="${NAMESPACE:-autoscaling-lab}"
  echo "[load] Deleting load-generator pods..."
  kubectl delete pods -n "${ns}" -l app=load-generator --ignore-not-found >/dev/null 2>&1 || true
  echo "[load] Load generator stopped (mode=pod)"
}

# ---------------------------------------------------------------------------
# stop_load_host
# ---------------------------------------------------------------------------
stop_load_host() {
  local stopped=0

  if [[ -f .state/load.pids ]]; then
    while IFS= read -r pid; do
      kill "${pid}" 2>/dev/null || true
    done < .state/load.pids
    rm -f .state/load.pids
    stopped=1
  fi

  # Backward compat with single-pid file
  if [[ -f .state/load.pid ]]; then
    kill "$(cat .state/load.pid)" 2>/dev/null || true
    rm -f .state/load.pid
    stopped=1
  fi

  if [[ "${stopped}" -eq 1 ]]; then
    echo "[load] Load generator stopped (mode=host)"
  else
    echo "[load] No host load PID found"
  fi
}

# ---------------------------------------------------------------------------
# stop_load
# ---------------------------------------------------------------------------
stop_load() {
  stop_load_pod
  stop_load_host
}

# ---------------------------------------------------------------------------
# status_load
# ---------------------------------------------------------------------------
status_load() {
  ensure_cluster_context 2>/dev/null || true
  local ns="${NAMESPACE:-autoscaling-lab}"

  local phase
  phase="$(kubectl -n "${ns}" get pod load-generator \
    --ignore-not-found \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "${phase}" == "Running" ]]; then
    echo "active (mode=pod)"
    return 0
  fi

  if [[ -f .state/load.pids ]]; then
    local any_alive=0
    while IFS= read -r pid; do
      if kill -0 "${pid}" 2>/dev/null; then
        any_alive=1; break
      fi
    done < .state/load.pids
    if [[ "${any_alive}" -eq 1 ]]; then
      echo "active (mode=host/background)"
      return 0
    fi
  fi

  if [[ -f .state/load.pid ]]; then
    if kill -0 "$(cat .state/load.pid)" 2>/dev/null; then
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
BACKGROUND_FILE=""
DO_STATUS=0
DO_STOP=0

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/load.sh --mode host [--preset hpa-proof]                     # foreground" >&2
  echo "       ./scripts/load.sh --mode host [--preset hpa-proof] --background <file> # background" >&2
  echo "       ./scripts/load.sh --mode pod  [--preset hpa-proof] [--concurrency <n>]" >&2
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
      if [[ ! "${CONCURRENCY}" =~ ^[0-9]+$ ]] || [[ "${CONCURRENCY}" -lt 1 ]] || [[ "${CONCURRENCY}" -gt 100 ]]; then
        echo "[load] --concurrency must be a number between 1 and 100" >&2; exit 2
      fi
      shift 2
      ;;
    --background)
      BACKGROUND_FILE="${2:?--background requires a logfile path}"
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

if [[ -n "${BACKGROUND_FILE}" ]]; then
  if [[ "${MODE}" != "host" ]]; then
    echo "[load] --background only supported with --mode host" >&2
    exit 2
  fi
  export BACKGROUND_LOG="${BACKGROUND_FILE}"
fi

case "${MODE}" in
  pod)  start_load_pod ;;
  host) start_load_host ;;
  "")
    echo "[load] No --mode specified." >&2
    exit 2
    ;;
esac
