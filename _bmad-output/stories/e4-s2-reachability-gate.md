# Story E4-S2 — Reachability Gate

**Epic:** E4 — Bootstrap & Reachability Gates
**Status:** Pending

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

| ID | Task | Status |
|---|---|---|
| 4.2.1 | Create `scripts/lib/gate-reachability.sh` — implement `gate_reachability` | Pending |
| 4.2.2 | Implement NodePort detection via `kubectl get svc -n <ns> -o jsonpath` | Pending |
| 4.2.3 | Implement curl smoke check with retry loop (3 attempts, 5s backoff) | Pending |
| 4.2.4 | Print `Lab URL: http://localhost:<port>` on pass | Pending |
