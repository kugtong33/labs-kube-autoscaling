# Story E6-S2 — `fix.sh` Dispatcher & Attempt 1 (Canonical)

**Epic:** E6 — HPA Failure Codes & Fix Dispatcher
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** `./scripts/fix.sh HPA-30X` to apply the canonical fix for that code, log the result, and tell me the next command,
**so that** recovery is a single deterministic action.

---

## Acceptance Criteria

- Accepts one positional arg (`HPA-301` through `HPA-306`); unknown → usage + exit 2
- Each fix function logs to `${FIX_DIR}/<code>.log` and writes `${FIX_DIR}/<code>.json`
- Every fix ends with `echo "Next command: ./scripts/up.sh --resume hpa_proof"`
- `log_fix_result` writes `{"code":"...","status":"...","note":"...","run_id":"..."}`

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 6.2.1 | Create `scripts/fix.sh` entrypoint with `CODE` arg parsing and `case` dispatch | Pending |
| 6.2.2 | Implement `log_fix_result` helper | Pending |
| 6.2.3 | Implement `fix_hpa_301` (Attempt 1): `kubectl apply -f k8s/hpa.yaml` + verify HPA exists | Pending |
| 6.2.4 | Implement `fix_hpa_302` (Attempt 1): apply `metrics-server.yaml` + rollout wait + verify `kubectl top nodes` | Pending |
| 6.2.5 | Implement `fix_hpa_303` (Attempt 1): `kubectl apply -f k8s/deployment.yaml` + rollout + verify CPU request | Pending |
| 6.2.6 | Implement `fix_hpa_304` (Attempt 1): `load.sh --mode ${LOAD_MODE}` + verify `--status` | Pending |
| 6.2.7 | Implement `fix_hpa_305` (Attempt 1): apply `k8s/presets/hpa-proof.yaml` + load preset start | Pending |
| 6.2.8 | Implement `fix_hpa_306` (Attempt 1): `load.sh --stop` + write `HPA_COOLDOWN_SEC=420` env override | Pending |
