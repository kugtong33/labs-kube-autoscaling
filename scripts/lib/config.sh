#!/usr/bin/env bash
# scripts/lib/config.sh — central configuration surface for the autoscaling lab
# All variables respect pre-set environment (${VAR:-default} pattern).
# Source this file; do not execute it directly.

[[ -n "${__CONFIG_SH:-}" ]] && return
__CONFIG_SH=1

# ---------------------------------------------------------------------------
# D3 Delivery Model
# ---------------------------------------------------------------------------
export APP_MODE="${APP_MODE:-landing}"      # landing | api
export LOAD_MODE="${LOAD_MODE:-pod}"        # pod | host
export PROFILE="${PROFILE:-tiny}"           # tiny | balanced | stretch

# ---------------------------------------------------------------------------
# Kubernetes coordinates
# ---------------------------------------------------------------------------
export CLUSTER_NAME="${CLUSTER_NAME:-autoscaling-lab}"
export NAMESPACE="${NAMESPACE:-autoscaling-lab}"
export APP_DEPLOYMENT="${APP_DEPLOYMENT:-sample-app}"
export APP_CONTAINER="${APP_CONTAINER:-app}"
export HPA_NAME="${HPA_NAME:-sample-app-hpa}"

# ---------------------------------------------------------------------------
# HPA proof timing (seconds)
# ---------------------------------------------------------------------------
export HPA_RAMP_SEC="${HPA_RAMP_SEC:-180}"
export HPA_COOLDOWN_SEC="${HPA_COOLDOWN_SEC:-240}"
export HPA_POLL_SEC="${HPA_POLL_SEC:-10}"

# ---------------------------------------------------------------------------
# Artifact paths (RUN_ID is set by up.sh at runtime)
# ---------------------------------------------------------------------------
export ARTIFACT_BASE="${ARTIFACT_BASE:-artifacts}"
export ARTIFACT_ROOT="${ARTIFACT_ROOT:-${ARTIFACT_BASE}/${RUN_ID:-unset}}"
export HPA_DIR="${HPA_DIR:-${ARTIFACT_ROOT}/hpa}"
export FIX_DIR="${FIX_DIR:-${ARTIFACT_ROOT}/fix}"

# ---------------------------------------------------------------------------
# get_max_replicas <profile>
# Outputs the maxReplicas integer for a given profile name.
# ---------------------------------------------------------------------------
get_max_replicas() {
  case "${1:-${PROFILE}}" in
    tiny)     echo 5 ;;
    balanced) echo 7 ;;
    stretch)  echo 10 ;;
    *)
      echo "[config] Unknown profile: '${1}'. Valid values: tiny, balanced, stretch" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# get_available_ram_mb
# Outputs available RAM in MB.
# Linux: free -m available column. macOS: vm_stat pages calculation.
# Unrecognised OS: outputs 99999 (skips guard) with a warning.
# ---------------------------------------------------------------------------
get_available_ram_mb() {
  local os
  os="$(uname -s 2>/dev/null || true)"

  case "${os}" in
    Linux)
      free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo 0
      ;;
    Darwin)
      # vm_stat reports pages (4 KB each); sum free + inactive for available
      local pages_free pages_inactive
      pages_free="$(vm_stat 2>/dev/null | awk '/Pages free/{gsub(/\./, "", $3); print $3}')"
      pages_inactive="$(vm_stat 2>/dev/null | awk '/Pages inactive/{gsub(/\./, "", $3); print $3}')"
      if [[ -n "${pages_free}" && -n "${pages_inactive}" ]]; then
        echo $(( (pages_free + pages_inactive) * 4096 / 1048576 ))
      else
        echo 0
      fi
      ;;
    *)
      echo "[config] Warning: OS not recognized, skipping memory guard" >&2
      echo 99999
      ;;
  esac
}

# Keep the old name as an alias for backwards compatibility.
get_available_memory_mb() { get_available_ram_mb; }

# ---------------------------------------------------------------------------
# ensure_cluster_context
# Switches the active kubectl context to kind-${CLUSTER_NAME}.
# Call this after the KinD cluster is known to exist (i.e. post-bootstrap
# or at the start of any entrypoint that assumes the cluster is running).
# ---------------------------------------------------------------------------
ensure_cluster_context() {
  local ctx="kind-${CLUSTER_NAME:-autoscaling-lab}"
  if ! kubectl config use-context "${ctx}" >/dev/null 2>&1; then
    echo "[config] ERROR: kubectl context '${ctx}' not found." >&2
    echo "[config] Is the KinD cluster running? Try: kind get clusters" >&2
    return 1
  fi
  echo "[config] kubectl context set to: ${ctx}"
}

# ---------------------------------------------------------------------------
# profile_admission_guard
# Warns (tiny, balanced) or blocks (stretch) when available RAM is below
# threshold. Call this at the top of up.sh before any provisioning.
# Returns non-zero only for stretch when RAM is insufficient.
# ---------------------------------------------------------------------------
profile_admission_guard() {
  local avail_mb
  avail_mb="$(get_available_ram_mb)"

  case "${PROFILE}" in
    tiny)
      if [[ "${avail_mb}" -lt 2048 ]]; then
        echo "[WARN] Profile 'tiny' requires 2GB node RAM but only ~${avail_mb}MB available." >&2
        echo "[WARN] Consider freeing RAM or reducing background workloads." >&2
      fi
      ;;
    balanced)
      if [[ "${avail_mb}" -lt 4096 ]]; then
        echo "[WARN] Profile 'balanced' requires 4GB node RAM but only ~${avail_mb}MB available." >&2
        echo "[WARN] Suggestion: set PROFILE=tiny to avoid instability." >&2
      fi
      ;;
    stretch)
      if [[ "${avail_mb}" -lt 8192 ]]; then
        echo "[ERROR] Profile 'stretch' requires 8GB node RAM. Only ~${avail_mb}MB available. Aborting." >&2
        echo "[ERROR] Use PROFILE=balanced or PROFILE=tiny." >&2
        return 1
      fi
      ;;
    *)
      echo "[config] Unknown profile: ${PROFILE}. Valid values: tiny, balanced, stretch" >&2
      return 1
      ;;
  esac
}
