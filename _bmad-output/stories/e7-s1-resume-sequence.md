# Story E7-S1 — Resume Sequence

**Epic:** E7 — Resume Path
**Status:** Done

---

## User Story

**As a** lab user,
**I want** `./scripts/up.sh --resume hpa_proof` to run only the gates needed after a fix,
**so that** I skip reprovisioning and go straight back to proving autoscaling.

---

## Acceptance Criteria

- `--resume hpa_proof` triggers sequence: `bootstrap_integrity → reachability_gate → hpa_proof → evidence_capture`
- `bootstrap_integrity` is read-only: checks `kind get clusters`, namespace exists, deployment healthy — no recreate
- Uses prior `RUN_ID` from `.state/last_run_id` unless `--run-id` is specified
- `--profile`, `--app-mode`, `--load-mode` args are respected in resumed gates
- Resume mode propagated to outcome resolver (`mode=resume`)

---

## Tasks

### Task 7.1.1 — Implement `gate_bootstrap_integrity` in `scripts/lib/gate-bootstrap.sh` (read-only kubectl checks)
- [x] Add `gate_bootstrap_integrity()` function to existing `scripts/lib/gate-bootstrap.sh`
- [x] Check KinD cluster exists: `kind get clusters 2>/dev/null | grep -q "autoscaling-lab"` or return non-zero
- [x] Check namespace exists: `kubectl get ns "${NAMESPACE}" >/dev/null 2>&1` or return non-zero
- [x] Check deployment healthy: `kubectl -n "${NAMESPACE}" rollout status deploy/"${APP_DEPLOYMENT}" --timeout=30s` or return non-zero
- [x] Check HPA exists: `kubectl -n "${NAMESPACE}" get hpa >/dev/null 2>&1` or return non-zero
- [x] On all checks passing: print `Bootstrap integrity: OK` and return 0
- [x] On any check failing: print which check failed with descriptive message; return non-zero
- [x] Function must NOT create, apply, or modify any resource (read-only constraint)

### Task 7.1.2 — Implement `resume_hpa_proof_run` sequence in `up.sh`
- [x] Add `resume_hpa_proof_run()` function to `scripts/up.sh` (or to a lib file sourced by it)
- [x] Call `run_gate "bootstrap_integrity" gate_bootstrap_integrity CRITICAL` as first gate
- [x] Call `run_gate "reachability" gate_reachability CRITICAL` as second gate
- [x] Call `run_gate "hpa_proof" gate_hpa_proof CRITICAL` as third gate
- [x] Call `run_gate "evidence_capture" gate_evidence_capture NON_CRITICAL` as fourth gate
- [x] After all gates, call `print_final_scorecard "resume"` to display results
- [x] Write `mode=resume` into the run's scorecard JSONL header entry

### Task 7.1.3 — Add `--resume`, `--run-id`, `--profile`, `--app-mode`, `--load-mode` to `up.sh` `parse_args`
- [x] In `up.sh` `parse_args()` or equivalent arg-parsing block, handle `--resume <target>`: set `RESUME_TARGET="${2}"` and shift 2
- [x] Handle `--run-id <id>`: set `RUN_ID_OVERRIDE="${2}"` and shift 2
- [x] Handle `--profile <value>`: set `PROFILE="${2}"` and shift 2; validate against `tiny|balanced|stretch`
- [x] Handle `--app-mode <value>`: set `APP_MODE="${2}"` and shift 2; validate against `landing|api`
- [x] Handle `--load-mode <value>`: set `LOAD_MODE="${2}"` and shift 2; validate against `pod|host`
- [x] After parsing: if `RESUME_TARGET` is set, call `resume_hpa_proof_run`; else call full `run`
- [x] Print usage if unknown flag encountered

### Task 7.1.4 — Implement `resolve_run_id` resume branch: reads `.state/last_run_id` when `--resume` set
- [x] In `resolve_run_id()` (or inline in `up.sh`): if `RUN_ID_OVERRIDE` is set, use it as `RUN_ID`
- [x] Else if `RESUME_TARGET` is set: read `RUN_ID` from `.state/last_run_id` (fail with message if file missing)
- [x] Else (full run): generate new `RUN_ID` using `date -u +%Y%m%dT%H%M%SZ` or UUID
- [x] After resolving, write `RUN_ID` to `.state/last_run_id` (overwrite)
- [x] Export `RUN_ID` so all sourced lib files inherit it: `export RUN_ID`

### Task 7.1.5 — Propagate `RESUME_TARGET` to `print_next_action_from_scorecard` for mode differentiation
- [x] Export `RESUME_TARGET` after it is set in `parse_args`: `export RESUME_TARGET`
- [x] In `print_next_action_from_scorecard()` (in `scripts/lib/scorecard.sh`): pass `RESUME_TARGET` as arg to `outcome-resolver.js`
- [x] Resolver receives `mode=resume` when `RESUME_TARGET` is non-empty, `mode=full_run` otherwise
- [x] Verify that outcome resolver returns `LEARNING_READY_WITH_WARNINGS_RESUME` vs `LEARNING_READY_WITH_WARNINGS_FULL` correctly based on mode
