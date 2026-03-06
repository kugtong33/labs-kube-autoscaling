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

| ID | Task | Status |
|---|---|---|
| 2.2.1 | Implement `resolve_run_id` in `scripts/lib/run-context.sh` | Pending |
| 2.2.2 | Implement `init_artifacts` — create all artifact subdirectories | Pending |
| 2.2.3 | Implement `run_sequence` dispatcher with `case` statement routing gate names to gate functions | Pending |
| 2.2.4 | Implement `timeline.log` append on sequence start and each gate completion | Pending |
| 2.2.5 | Create `scripts/up.sh` entrypoint: parse args → `resolve_run_id` → `init_artifacts` → `run_sequence` → scorecard | Pending |
