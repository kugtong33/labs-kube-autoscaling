#!/usr/bin/env bash
# scripts/lib/failure-maps.sh — failure hint and next-command maps for HPA error codes
# Source this file; do not execute it directly.

[[ -n "${_FAILURE_MAPS_SH:-}" ]] && return
_FAILURE_MAPS_SH=1

# ---------------------------------------------------------------------------
# print_failure_hint <code>
#
# Prints a 4-line actionable block for the given HPA failure code:
#   [HPA-30X] <title>
#   Check: <command>
#   Fix:   <fix.sh invocation>
#   Retry: ./scripts/up.sh --resume hpa_proof
#
# Unknown codes print a generic block without crashing.
# ---------------------------------------------------------------------------
print_failure_hint() {
  local code="${1:-}"
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local hpa_dir="${HPA_DIR:-artifacts/unset/hpa}"

  case "${code}" in
    301)
      echo "[HPA-301] HPA resource not found"
      echo "Check: kubectl get hpa -n ${ns}"
      echo "Fix:   ./scripts/fix.sh HPA-301"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    302)
      echo "[HPA-302] Metrics server unavailable"
      echo "Check: kubectl top nodes"
      echo "Fix:   ./scripts/fix.sh HPA-302"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    303)
      echo "[HPA-303] CPU requests not set on deployment"
      echo "Check: kubectl -n ${ns} get deploy ${deploy} -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}'"
      echo "Fix:   ./scripts/fix.sh HPA-303"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    304)
      echo "[HPA-304] Load generator failed to start"
      echo "Check: ./scripts/load.sh --status"
      echo "Fix:   ./scripts/fix.sh HPA-304"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    305)
      echo "[HPA-305] No scale-up observed during ramp window"
      echo "Check: cat ${hpa_dir}/replica_samples.csv"
      echo "Fix:   ./scripts/fix.sh HPA-305"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    306)
      echo "[HPA-306] Cooldown not observed within window"
      echo "Check: cat ${hpa_dir}/replica_samples.csv"
      echo "Fix:   ./scripts/fix.sh HPA-306"
      echo "Retry: ./scripts/up.sh --resume hpa_proof"
      echo ""
      ;;
    *)
      echo "[GENERIC-${code}] Unknown failure code"
      echo "Check: Review gate logs in ${ARTIFACT_ROOT:-artifacts/unset}/gates/"
      echo "Fix:   Inspect the output above for details"
      echo "Retry: ./scripts/up.sh"
      echo ""
      ;;
  esac
}

# ---------------------------------------------------------------------------
# print_next_command_for_code <code>
#
# Outputs the single next command string for the given failure code.
# Callers capture with $(...).
# ---------------------------------------------------------------------------
print_next_command_for_code() {
  local code="${1:-}"

  case "${code}" in
    301|302|303|304|305|306)
      echo "./scripts/fix.sh HPA-${code}"
      ;;
    *)
      echo "./scripts/up.sh"
      ;;
  esac
}
