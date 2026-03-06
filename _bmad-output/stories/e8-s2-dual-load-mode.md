# Story E8-S2 — Dual Load Mode

**Epic:** E8 — D3 Delivery Model: App & Load Modes
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** `LOAD_MODE=pod|host` to switch between in-cluster and host-side load generation,
**so that** I can prove autoscaling via both isolated and real-world network paths.

---

## Acceptance Criteria

- `load.sh --mode pod`: starts a load-generator pod in namespace; labeled for cleanup
- `load.sh --mode host`: starts a host-side curl loop; PID tracked in `.state/load.pid`
- `load.sh --status`: prints `active` or `stopped`
- `load.sh --stop`: cleans up pod or kills PID
- `load.sh --preset hpa-proof`: applies cap-aware low-intensity settings

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 8.2.1 | Create `scripts/load.sh` with `--mode`, `--status`, `--stop`, `--preset` arg parsing | Pending |
| 8.2.2 | Implement `start_load_pod`: deploy `busybox` curl-loop pod, labeled `app=load-generator` | Pending |
| 8.2.3 | Implement `start_load_host`: background curl loop; write PID to `.state/load.pid` | Pending |
| 8.2.4 | Implement `stop_load_pod`: delete pods by label | Pending |
| 8.2.5 | Implement `stop_load_host`: read + kill PID from `.state/load.pid` | Pending |
| 8.2.6 | Implement `status_load`: check pod running or PID alive | Pending |
| 8.2.7 | Implement `--preset hpa-proof`: set low RPS/concurrency matching `tiny` profile | Pending |
