# Story E2-S2 — Run Sequence & Artifact Initialization

**Epic:** E2 — Deterministic Gate Engine
**Status:** Pending

---

## User Story

**As a** lab runner,
**I want** a `run_sequence <name> <gates...>` dispatcher and artifact directory initialization,
**so that** full-run and resume sequences share the same routing logic and every run has an isolated artifact directory.

---

## Acceptance Criteria

- `resolve_run_id` sets `RUN_ID`, `ARTIFACT_ROOT`, `SCORECARD_FILE`, `GATE_DIR`; persists `RUN_ID` to `.state/last_run_id`
- `init_artifacts` creates `${ARTIFACT_ROOT}`, `${GATE_DIR}`, `${HPA_DIR}`, `.state/`
- `run_sequence <name> <gate_names...>` routes each gate name to correct `run_gate` call
- Logs sequence start to `${ARTIFACT_ROOT}/timeline.log`

---

## Tasks

### Task 2.2.1 — Implement `resolve_run_id` in `scripts/lib/run-context.sh`
- [ ] Create `scripts/lib/run-context.sh` with sourcing guard
- [ ] Define `resolve_run_id()` function
- [ ] If `RUN_ID_ARG` set: use it directly
- [ ] Else if `RESUME_TARGET` set and `.state/last_run_id` exists: read from file
- [ ] Else: generate `RUN_ID=$(date +%Y%m%d-%H%M%S)`
- [ ] Export `RUN_ID`
- [ ] Export `ARTIFACT_ROOT="artifacts/${RUN_ID}"`
- [ ] Export `SCORECARD_FILE="${ARTIFACT_ROOT}/scorecard.jsonl"`
- [ ] Export `GATE_DIR="${ARTIFACT_ROOT}/gates"`
- [ ] Export `HPA_DIR="${ARTIFACT_ROOT}/hpa"`
- [ ] Write `RUN_ID` to `.state/last_run_id`

### Task 2.2.2 — Implement `init_artifacts`
- [ ] Define `init_artifacts()` function
- [ ] Create `${ARTIFACT_ROOT}` with `mkdir -p`
- [ ] Create `${GATE_DIR}` with `mkdir -p`
- [ ] Create `${HPA_DIR}` with `mkdir -p`
- [ ] Create `.state/` with `mkdir -p`

### Task 2.2.3 — Implement `run_sequence` dispatcher
- [ ] Define `run_sequence <sequence_name> <gate_names...>` function
- [ ] Log sequence start to `${ARTIFACT_ROOT}/timeline.log`
- [ ] Route `bootstrap_gate` → `run_gate "bootstrap_gate" "CRITICAL" "gate_bootstrap"`
- [ ] Route `bootstrap_integrity` → `run_gate "bootstrap_integrity" "CRITICAL" "gate_bootstrap_integrity"`
- [ ] Route `reachability_gate` → `run_gate "reachability_gate" "CRITICAL" "gate_reachability"`
- [ ] Route `hpa_proof` → `run_gate "hpa_proof" "CRITICAL" "gate_hpa_proof"`
- [ ] Route `evidence_capture` → `run_gate "evidence_capture" "NON_CRITICAL" "gate_evidence_capture"`
- [ ] Route `teardown_integrity` → `run_gate "teardown_integrity" "NON_CRITICAL" "gate_teardown_integrity"`
- [ ] Unknown gate name → `echo "Unknown gate: ${g}"; exit 112`

### Task 2.2.4 — Implement `timeline.log` append
- [ ] Append `[<timestamp>] START sequence: <sequence_name>` on sequence start
- [ ] Append `[<timestamp>] GATE <name>: <status>` after each gate completes

### Task 2.2.5 — Create `scripts/up.sh` entrypoint
- [ ] Create `scripts/up.sh` with shebang and `set -euo pipefail`
- [ ] Source all lib files: `config.sh`, `run-context.sh`, `gate-runner.sh`, `failure-maps.sh`, `scorecard.sh`, and all gate libs
- [ ] Implement `parse_args "$@"` (handles `--resume`, `--run-id`, `--profile`, `--app-mode`, `--load-mode`)
- [ ] Call `profile_admission_guard`
- [ ] Call `resolve_run_id`
- [ ] Call `init_artifacts`
- [ ] Branch: if `RESUME_TARGET=hpa_proof` call `resume_hpa_proof_run`, else call full-run sequence
- [ ] Call `print_final_scorecard`
