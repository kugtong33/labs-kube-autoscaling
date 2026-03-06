# Story E9-S2 — Teardown & Integrity Gate

**Epic:** E9 — Evidence Capture & Teardown
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** `./scripts/down.sh` to cleanly remove all lab resources and verify re-run is possible,
**so that** every lifecycle ends reproducibly.

---

## Acceptance Criteria

- `down.sh` deletes namespace (`kubectl delete ns autoscaling-lab`)
- `down.sh` optionally deletes KinD cluster (`--delete-cluster` flag or default behavior TBD)
- `--preserve-artifacts` skips artifact directory deletion
- `gate_teardown_integrity` (NON_CRITICAL): verifies cluster still listed or namespace deleted
- After teardown, `up.sh` can be re-run cleanly

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 9.2.1 | Create `scripts/down.sh` with `--run-id`, `--preserve-artifacts`, `--delete-cluster` arg parsing | Pending |
| 9.2.2 | Implement namespace deletion with confirmation output | Pending |
| 9.2.3 | Implement optional KinD cluster deletion | Pending |
| 9.2.4 | Implement `gate_teardown_integrity` in `scripts/lib/gate-teardown.sh` | Pending |
