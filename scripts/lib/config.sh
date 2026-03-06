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
export NAMESPACE="${NAMESPACE:-autoscaling-lab}"
export APP_DEPLOYMENT="${APP_DEPLOYMENT:-sample-app}"
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
# get_available_memory_mb
# Outputs available RAM in MB. Returns 0 (skip guard) when undetectable.
# ---------------------------------------------------------------------------
get_available_memory_mb() {
  local os
  os="$(uname -s 2>/dev/null || true)"

  case "${os}" in
    Linux)
      free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo 0
      ;;
    Darwin)
      # vm_stat reports pages (4 KB each); sum free + inactive for available
      local pages_free pages_inactive page_size_kb=4
      pages_free="$(vm_stat 2>/dev/null | awk '/Pages free/{gsub(/\./, "", $3); print $3}')"
      pages_inactive="$(vm_stat 2>/dev/null | awk '/Pages inactive/{gsub(/\./, "", $3); print $3}')"
      if [[ -n "${pages_free}" && -n "${pages_inactive}" ]]; then
        echo $(( (pages_free + pages_inactive) * page_size_kb / 1024 ))
      else
        echo 0
      fi
      ;;
    *)
      # Unrecognised OS — skip guard gracefully
      echo 0
      ;;
  esac
}

# ---------------------------------------------------------------------------
# profile_admission_guard
# Warns (balanced) or blocks (stretch) when available RAM is below threshold.
# Call this at the top of up.sh before any provisioning.
# ---------------------------------------------------------------------------
profile_admission_guard() {
  local avail_mb
  avail_mb="$(get_available_memory_mb)"

  # If detection returned 0 (unavailable), skip the guard entirely
  if [[ "${avail_mb}" -eq 0 ]]; then
    echo "[config] Memory detection unavailable — skipping profile admission guard." >&2
    return 0
  fi

  case "${PROFILE}" in
    balanced)
      if [[ "${avail_mb}" -lt 4096 ]]; then
        echo "[WARN] Profile 'balanced' recommends ≥4GB RAM but only ~${avail_mb}MB available." >&2
        echo "[WARN] Suggestion: set PROFILE=tiny to avoid instability." >&2
      fi
      ;;
    stretch)
      if [[ "${avail_mb}" -lt 8192 ]]; then
        echo "[ERROR] Profile 'stretch' requires ≥8GB RAM. Only ~${avail_mb}MB available. Aborting." >&2
        echo "[ERROR] Use PROFILE=balanced or PROFILE=tiny." >&2
        return 1
      fi
      ;;
    tiny|*)
      # tiny always passes; unknown profiles are validated elsewhere
      ;;
  esac
}
