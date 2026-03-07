#!/usr/bin/env bash
# scripts/lib/app-mode.sh — app mode and profile routing
# Source this file; do not execute it directly.

[[ -n "${__APP_MODE_SH:-}" ]] && return
__APP_MODE_SH=1

# ---------------------------------------------------------------------------
# apply_app_mode
#
# Applies the correct deployment, service, and HPA manifests based on
# APP_MODE (landing|api) and PROFILE (tiny|balanced|stretch).
#
# Reads from environment:
#   APP_MODE     — landing | api
#   PROFILE      — tiny | balanced | stretch
#   NAMESPACE    — target namespace (default: autoscaling-lab)
#   APP_DEPLOYMENT — deployment name (default: sample-app)
# ---------------------------------------------------------------------------
apply_app_mode() {
  local app_mode="${APP_MODE:-landing}"
  local profile="${PROFILE:-tiny}"
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"

  # Validate APP_MODE
  case "${app_mode}" in
    landing|api) ;;
    *)
      echo "[app-mode] ERROR: invalid APP_MODE '${app_mode}'. Valid: landing, api" >&2
      return 1
      ;;
  esac

  # Validate PROFILE
  case "${profile}" in
    tiny|balanced|stretch) ;;
    *)
      echo "[app-mode] ERROR: invalid PROFILE '${profile}'. Valid: tiny, balanced, stretch" >&2
      return 1
      ;;
  esac

  echo "[app-mode] Applying APP_MODE=${app_mode}, PROFILE=${profile}..."

  # Apply deployment
  echo "[app-mode] Applying k8s/app/${app_mode}/deployment.yaml..."
  kubectl apply -f "k8s/app/${app_mode}/deployment.yaml" -n "${ns}"

  # Apply service
  echo "[app-mode] Applying k8s/app/${app_mode}/service.yaml..."
  kubectl apply -f "k8s/app/${app_mode}/service.yaml" -n "${ns}"

  # Apply HPA
  echo "[app-mode] Applying k8s/hpa-${profile}.yaml..."
  kubectl apply -f "k8s/hpa-${profile}.yaml" -n "${ns}"

  # Wait for deployment rollout
  echo "[app-mode] Waiting for deployment '${deploy}' rollout (timeout 180s)..."
  kubectl -n "${ns}" rollout status "deploy/${deploy}" --timeout=180s

  echo "[app-mode] App mode: ${app_mode}, Profile: ${profile} — applied"
}
