# Story E4-S2 — Reachability Gate

**Epic:** E4 — Bootstrap & Reachability Gates
**Status:** Done

---

## User Story

**As a** lab user,
**I want** a reachability gate that confirms the app is browser-accessible before load testing begins,
**so that** load starts against a provably live endpoint.

---

## Acceptance Criteria

- Detects NodePort for the service
- Smoke-checks `http://localhost:<nodeport>/` with curl (retry up to 3x with 5s backoff)
- Prints the lab URL to console: `Lab URL: http://localhost:<port>`
- Returns non-zero if HTTP response is not 2xx after retries

---

## Tasks

### Task 4.2.1 — Create `scripts/lib/gate-reachability.sh` — implement `gate_reachability`
- [x] Create file with shebang and sourcing guard
- [x] Define `gate_reachability()` function skeleton
- [x] Source required lib files

### Task 4.2.2 — Implement NodePort detection
- [x] Run `kubectl get svc -n ${NAMESPACE} ${APP_DEPLOYMENT} -o jsonpath='{.spec.ports[0].nodePort}'`
- [x] Store result as `NODE_PORT`
- [x] Verify `NODE_PORT` is non-empty; return non-zero if missing

### Task 4.2.3 — Implement curl smoke check with retry loop
- [x] Initialize `attempt=1`, `max_attempts=3`, `backoff=5`
- [x] Loop: run `curl -sf --max-time 5 http://localhost:${NODE_PORT}/`
- [x] Return 0 on first successful (2xx) response
- [x] Sleep `${backoff}` seconds between attempts
- [x] Return non-zero after all 3 attempts exhausted

### Task 4.2.4 — Print Lab URL on pass
- [x] Print `Lab URL: http://localhost:${NODE_PORT}` after successful smoke check
