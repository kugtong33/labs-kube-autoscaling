# Story E9-S1 — Evidence Capture Gate

**Epic:** E9 — Evidence Capture & Teardown
**Status:** Done

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

### Task 9.1.1 — Create `scripts/lib/gate-evidence.sh` — implement `gate_evidence_capture`
- [x] Create `scripts/lib/gate-evidence.sh` with shebang and sourcing guard
- [x] Define `gate_evidence_capture()` function
- [x] Declare local variables: `ns="${NAMESPACE}"`, `artifact_dir="${ARTIFACT_ROOT}"`, `evidence_dir="${artifact_dir}/evidence"`
- [x] Create `${evidence_dir}` if it does not exist: `mkdir -p "${evidence_dir}"`
- [x] Capture `kubectl get all -n "${ns}"` → `${evidence_dir}/all-resources.txt` (wrapped in `|| true`)
- [x] Capture `kubectl -n "${ns}" describe hpa` → `${evidence_dir}/hpa-describe.txt` (wrapped in `|| true`)
- [x] Copy `${HPA_DIR}/replica_samples.csv` to `${evidence_dir}/replica_samples.csv` if it exists (wrapped in `|| true`)
- [x] Capture `kubectl -n "${ns}" get events --sort-by=.metadata.creationTimestamp` → `${evidence_dir}/events.txt` (wrapped in `|| true`)
- [x] After all captures, call `generate_evidence_checklist` to produce the checklist
- [x] Return 0 (non-critical: failures inside are absorbed via `|| true`; checklist reflects what was captured)

### Task 9.1.2 — Implement `evidence-checklist.md` generator with checkboxes: output captured, CSV present, screenshot placeholder
- [x] Define `generate_evidence_checklist()` function within `gate-evidence.sh`
- [x] Write `# Evidence Checklist — Run ID: ${RUN_ID}` header to `${ARTIFACT_ROOT}/evidence-checklist.md`
- [x] Add `Generated: $(date -u +%FT%TZ)` line
- [x] Add checkbox: `- [x] all-resources.txt captured` if file exists, `- [x] all-resources.txt MISSING` if not
- [x] Add checkbox: `- [x] hpa-describe.txt captured` if file exists, `- [x] hpa-describe.txt MISSING` if not
- [x] Add checkbox: `- [x] replica_samples.csv present` if file exists, `- [x] replica_samples.csv MISSING` if not
- [x] Add checkbox: `- [x] events.txt captured` if file exists, `- [x] events.txt MISSING` if not
- [x] Add placeholder: `- [x] Screenshot of HPA scale-up graph (manual step)` — always unchecked
- [x] Add placeholder: `- [x] Reviewer sign-off` — always unchecked
- [x] Print `Evidence checklist written: ${ARTIFACT_ROOT}/evidence-checklist.md`

### Task 9.1.3 — Create `scripts/collect-evidence.sh` — standalone re-run with `--run-id` and `--from-resume` args
- [x] Create `scripts/collect-evidence.sh` with shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- [x] Source `scripts/lib/config.sh` and `scripts/lib/gate-evidence.sh`
- [x] Parse `--run-id <id>`: set `RUN_ID="${2}"` and export; shift 2
- [x] Parse `--from-resume`: set `FROM_RESUME=1`; shift
- [x] After parsing: if `RUN_ID` is not set, read from `.state/last_run_id`; fail with message if missing
- [x] Set `ARTIFACT_ROOT="${ARTIFACT_BASE}/${RUN_ID}"` (where `ARTIFACT_BASE` is from config)
- [x] Call `gate_evidence_capture`
- [x] Print completion message: `Evidence collected for run ${RUN_ID}. See ${ARTIFACT_ROOT}/evidence-checklist.md`
- [x] Exit 0 regardless of individual capture failures (non-critical contract)
