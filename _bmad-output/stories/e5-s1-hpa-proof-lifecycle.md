# Story E5-S1 — HPA Proof Lifecycle

**Epic:** E5 — HPA Proof Gate
**Status:** Pending

---

## User Story

**As a** lab runner,
**I want** a deterministic HPA proof gate that measures baseline, loads the service, observes scale-up, stops load, and observes cooldown,
**so that** autoscaling behavior is provably demonstrated with a timestamped artifact trail.

---

## Acceptance Criteria

- Precondition checks: HPA exists → 301; metrics available → 302; CPU requests set → 303
- Captures baseline replica count before load starts
- Starts load via `start_load <mode>` → 304 if fails
- Polls replicas every `HPA_POLL_SEC` for `HPA_RAMP_SEC`; tracks `max_seen`; exits loop on timeout
- If `max_seen <= baseline` after ramp: returns 305
- Stops load; polls for cooldown up to `HPA_COOLDOWN_SEC`; returns 306 if no decrease observed
- Writes all HPA artifacts to `${HPA_DIR}`

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 5.1.1 | Create `scripts/lib/gate-hpa-proof.sh` — implement `gate_hpa_proof` | Pending |
| 5.1.2 | Implement precondition checks (301, 302, 303) | Pending |
| 5.1.3 | Implement baseline capture and `replica_samples.csv` with `ts,replicas` rows | Pending |
| 5.1.4 | Implement scale-up polling loop with `max_seen` tracker | Pending |
| 5.1.5 | Implement cooldown polling loop | Pending |
| 5.1.6 | Implement `start_load` / `stop_load` delegators (route to `load.sh`) | Pending |
