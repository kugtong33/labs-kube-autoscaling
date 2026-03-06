# Story E7-S1 — Resume Sequence

**Epic:** E7 — Resume Path
**Status:** Pending

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

| ID | Task | Status |
|---|---|---|
| 7.1.1 | Implement `gate_bootstrap_integrity` in `scripts/lib/gate-bootstrap.sh` (read-only kubectl checks) | Pending |
| 7.1.2 | Implement `resume_hpa_proof_run` sequence in `up.sh` | Pending |
| 7.1.3 | Add `--resume`, `--run-id`, `--profile`, `--app-mode`, `--load-mode` to `up.sh` `parse_args` | Pending |
| 7.1.4 | Implement `resolve_run_id` resume branch: reads `.state/last_run_id` when `--resume` set | Pending |
| 7.1.5 | Propagate `RESUME_TARGET` to `print_next_action_from_scorecard` for mode differentiation | Pending |
