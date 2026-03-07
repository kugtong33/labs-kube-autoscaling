#!/usr/bin/env bash
# scripts/lib/gate-evidence.sh — evidence capture gate
# NON_CRITICAL: failure does not block success.
# Source this file; do not execute it directly.

[[ -n "${__GATE_EVIDENCE_SH:-}" ]] && return
__GATE_EVIDENCE_SH=1

# ---------------------------------------------------------------------------
# generate_evidence_checklist
#
# Writes ${ARTIFACT_ROOT}/evidence-checklist.md with pass/fail checkboxes
# for each captured artifact.
# ---------------------------------------------------------------------------
generate_evidence_checklist() {
  local artifact_root="${ARTIFACT_ROOT:-artifacts/unset}"
  local evidence_dir="${artifact_root}/evidence"
  local checklist="${artifact_root}/evidence-checklist.md"

  _checkbox() {
    local file="$1" label="$2"
    if [[ -f "${file}" ]]; then
      echo "- [x] ${label} captured"
    else
      echo "- [ ] ${label} MISSING"
    fi
  }

  {
    echo "# Evidence Checklist — Run ID: ${RUN_ID:-unknown}"
    echo ""
    echo "Generated: $(date -u +%FT%TZ)"
    echo ""
    _checkbox "${evidence_dir}/all-resources.txt"   "all-resources.txt"
    _checkbox "${evidence_dir}/hpa-describe.txt"    "hpa-describe.txt"
    _checkbox "${evidence_dir}/replica_samples.csv" "replica_samples.csv"
    _checkbox "${evidence_dir}/events.txt"          "events.txt"
    echo "- [ ] Screenshot of HPA scale-up graph (manual step)"
    echo "- [ ] Reviewer sign-off"
  } > "${checklist}"

  echo "[evidence] Evidence checklist written: ${checklist}"
}

# ---------------------------------------------------------------------------
# gate_evidence_capture
#
# Collects kubectl state snapshots into ${ARTIFACT_ROOT}/evidence/.
# Calls generate_evidence_checklist after all captures.
# Always returns 0 — failures are absorbed via || true.
# ---------------------------------------------------------------------------
gate_evidence_capture() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local artifact_dir="${ARTIFACT_ROOT:-artifacts/unset}"
  local evidence_dir="${artifact_dir}/evidence"

  mkdir -p "${evidence_dir}"

  echo "[evidence] Capturing kubectl get all..."
  kubectl get all -n "${ns}" > "${evidence_dir}/all-resources.txt" 2>&1 || true

  echo "[evidence] Capturing kubectl describe hpa..."
  kubectl -n "${ns}" describe hpa > "${evidence_dir}/hpa-describe.txt" 2>&1 || true

  echo "[evidence] Copying replica_samples.csv..."
  local hpa_dir="${HPA_DIR:-${artifact_dir}/hpa}"
  cp "${hpa_dir}/replica_samples.csv" "${evidence_dir}/replica_samples.csv" 2>/dev/null || true

  echo "[evidence] Capturing kubectl events..."
  kubectl -n "${ns}" get events --sort-by=.metadata.creationTimestamp \
    > "${evidence_dir}/events.txt" 2>&1 || true

  generate_evidence_checklist

  return 0
}
