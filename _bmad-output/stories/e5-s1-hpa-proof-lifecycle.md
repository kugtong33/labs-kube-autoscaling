# Story E5-S1 — HPA Proof Lifecycle

**Epic:** E5 — HPA Proof Gate
**Status:** Done

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

### Task 5.1.1 — Create `scripts/lib/gate-hpa-proof.sh` — implement `gate_hpa_proof`
- [x] Create file with shebang and sourcing guard
- [x] Define `gate_hpa_proof()` function
- [x] Declare all local variables: `ns`, `deploy`, `hpa`, `load_mode`, `ramp_sec`, `cool_sec`, `poll_sec`

### Task 5.1.2 — Implement precondition checks (301, 302, 303)
- [x] Check HPA exists: `kubectl -n ${ns} get hpa ${hpa} >/dev/null 2>&1 || return 301`
- [x] Check metrics available: `kubectl top nodes >/dev/null 2>/dev/null || return 302`
- [x] Check top pods: `kubectl -n ${ns} top pods >/dev/null 2>/dev/null || return 302`
- [x] Check CPU request set: `kubectl -n ${ns} get deploy ${deploy} -o jsonpath='{...cpu}' | grep -q . || return 303`

### Task 5.1.3 — Implement baseline capture and `replica_samples.csv`
- [x] Get `baseline` from `kubectl -n ${ns} get deploy ${deploy} -o jsonpath='{.status.replicas}'`
- [x] Default `baseline=1` if empty
- [x] Set `max_seen=${baseline}`
- [x] Write `ts,replicas` header to `${HPA_DIR}/replica_samples.csv`

### Task 5.1.4 — Implement scale-up polling loop
- [x] Initialize `elapsed=0`
- [x] Loop while `elapsed < ramp_sec`
- [x] Poll current replica count from deployment
- [x] Append `$(date -u +%FT%TZ),${current}` row to CSV
- [x] Update `max_seen` if `current > max_seen`
- [x] Sleep `${poll_sec}`; increment `elapsed`
- [x] After loop: if `max_seen <= baseline` call `stop_load` and `return 305`

### Task 5.1.5 — Implement cooldown polling loop
- [x] Call `stop_load "${LOAD_MODE}"`
- [x] Initialize `elapsed=0`, `cooled=0`
- [x] Loop while `elapsed < cool_sec`
- [x] Poll current replica count; append to CSV
- [x] If `current < max_seen`: set `cooled=1` and break
- [x] Sleep `${poll_sec}`; increment `elapsed`
- [x] After loop: if `cooled -ne 1` return 306

### Task 5.1.6 — Implement `start_load` / `stop_load` delegators
- [x] Define `start_load <mode>`: calls `./scripts/load.sh --mode "${mode}"`; return its exit code
- [x] Define `stop_load <mode>`: calls `./scripts/load.sh --stop`; return its exit code
