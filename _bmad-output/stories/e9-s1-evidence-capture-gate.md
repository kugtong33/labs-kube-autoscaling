# Story E9-S1 — Evidence Capture Gate

**Epic:** E9 — Evidence Capture & Teardown
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** a non-critical evidence gate that collects kubectl state snapshots and generates a checklist,
**so that** I have a complete, reviewer-ready evidence bundle after every successful proof.

---

## Acceptance Criteria

- `gate_evidence_capture` collects: `kubectl get all -n <ns>`, `kubectl describe hpa`, replica samples CSV check
- Generates `${ARTIFACT_ROOT}/evidence-checklist.md` with pass/fail checkboxes
- NON_CRITICAL: failure does not block success; emits warn + suggests `collect-evidence.sh`
- `scripts/collect-evidence.sh` re-runs evidence capture standalone (accepts `--run-id`, `--from-resume`)

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 9.1.1 | Create `scripts/lib/gate-evidence.sh` — implement `gate_evidence_capture` | Pending |
| 9.1.2 | Implement `evidence-checklist.md` generator with checkboxes: output captured, CSV present, screenshot placeholder | Pending |
| 9.1.3 | Create `scripts/collect-evidence.sh` — standalone re-run with `--run-id` and `--from-resume` args | Pending |
