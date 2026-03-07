# Story E8-S2 — Dual Load Mode

**Epic:** E8 — D3 Delivery Model: App & Load Modes
**Status:** Done

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

### Task 8.2.1 — Create `scripts/load.sh` with `--mode`, `--status`, `--stop`, `--preset` arg parsing
- [x] Create `scripts/load.sh` with shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- [x] Source `scripts/lib/config.sh` for `NAMESPACE`, `APP_DEPLOYMENT`, `LOAD_MODE`
- [x] Parse args in a `while [[ $# -gt 0 ]]; do case "$1"` loop
- [x] Handle `--mode <value>`: set `MODE="${2}"` and shift 2; validate `pod|host`
- [x] Handle `--status`: call `status_load` and exit
- [x] Handle `--stop`: call `stop_load` and exit
- [x] Handle `--preset <value>`: set `PRESET="${2}"` and shift 2
- [x] Handle `--concurrency <n>`: set `CONCURRENCY="${2}"` and shift 2 (optional, default 10)
- [x] After parsing: if `MODE` is set, call appropriate `start_load_*` function
- [x] Print usage if no recognized args or missing required values

### Task 8.2.2 — Implement `start_load_pod`: deploy `busybox` curl-loop pod, labeled `app=load-generator`
- [x] Define `start_load_pod()` function
- [x] Construct kubectl run command: `kubectl run load-generator -n "${NAMESPACE}" --image=busybox --restart=Never --labels="app=load-generator,managed-by=load-sh" -- /bin/sh -c "while true; do wget -q -O- http://${APP_DEPLOYMENT}/; sleep 0.1; done"`
- [x] If `PRESET=hpa-proof`: adjust sleep to `0.5` (lower intensity) instead of `0.1`
- [x] If pod already exists, delete and recreate: `kubectl delete pod load-generator -n "${NAMESPACE}" --ignore-not-found` before run
- [x] After start, verify pod is running: `kubectl -n "${NAMESPACE}" get pod load-generator` within 30s
- [x] Print `Load generator started (mode=pod)`

### Task 8.2.3 — Implement `start_load_host`: background curl loop; write PID to `.state/load.pid`
- [x] Define `start_load_host()` function
- [x] Detect NodePort: `NODE_PORT=$(kubectl get svc -n "${NAMESPACE}" "${APP_DEPLOYMENT}" -o jsonpath='{.spec.ports[0].nodePort}')`
- [x] Start background curl loop: `while true; do curl -sf --max-time 2 "http://localhost:${NODE_PORT}/" >/dev/null 2>&1; sleep 0.1; done &`
- [x] Capture PID: `LOAD_PID=$!`
- [x] Write PID: `echo "${LOAD_PID}" > .state/load.pid`
- [x] If `PRESET=hpa-proof`: use `sleep 0.5` instead of `0.1`
- [x] Print `Load generator started (mode=host, pid=${LOAD_PID})`

### Task 8.2.4 — Implement `stop_load_pod`: delete pods by label
- [x] Define `stop_load_pod()` function
- [x] Run `kubectl delete pods -n "${NAMESPACE}" -l app=load-generator --ignore-not-found`
- [x] Verify no load-generator pods remain: `kubectl -n "${NAMESPACE}" get pods -l app=load-generator` should return empty
- [x] Print `Load generator stopped (mode=pod)`

### Task 8.2.5 — Implement `stop_load_host`: read + kill PID from `.state/load.pid`
- [x] Define `stop_load_host()` function
- [x] Check `.state/load.pid` exists; if not, print `No host load PID found` and return 0 (idempotent)
- [x] Read PID: `LOAD_PID=$(cat .state/load.pid)`
- [x] Kill process: `kill "${LOAD_PID}" 2>/dev/null || true`
- [x] Remove PID file: `rm -f .state/load.pid`
- [x] Print `Load generator stopped (mode=host, pid=${LOAD_PID})`

### Task 8.2.6 — Implement `status_load`: check pod running or PID alive
- [x] Define `status_load()` function
- [x] Check pod mode: `kubectl -n "${NAMESPACE}" get pod load-generator --ignore-not-found -o jsonpath='{.status.phase}'` — if `Running`, print `active (mode=pod)` and return 0
- [x] Check host mode: if `.state/load.pid` exists and `kill -0 $(cat .state/load.pid) 2>/dev/null`, print `active (mode=host)` and return 0
- [x] Otherwise print `stopped` and return 0

### Task 8.2.7 — Implement `--preset hpa-proof`: set low RPS/concurrency matching `tiny` profile
- [x] Define `apply_preset()` function accepting preset name
- [x] For `hpa-proof` preset: export `LOAD_CONCURRENCY=5` and `LOAD_SLEEP_SEC=0.5`
- [x] Document preset intent: low enough to avoid overwhelming the tiny node, high enough to trigger HPA at `averageUtilization=50`
- [x] `start_load_pod` and `start_load_host` both read `LOAD_CONCURRENCY` and `LOAD_SLEEP_SEC` if set
- [x] Print `Preset applied: hpa-proof (concurrency=5, sleep=0.5s)`
