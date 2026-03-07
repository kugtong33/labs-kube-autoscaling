# Story E6-S2 — `fix.sh` Dispatcher & Attempt 1 (Canonical)

**Epic:** E6 — HPA Failure Codes & Fix Dispatcher
**Status:** Done

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

### Task 6.2.1 — Create `scripts/fix.sh` entrypoint with `CODE` arg parsing and `case` dispatch
- [x] Create `scripts/fix.sh` with shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- [x] Source `scripts/lib/config.sh` to get `NAMESPACE`, `FIX_DIR`, `RUN_ID`, `ARTIFACT_ROOT`
- [x] Source `scripts/lib/failure-maps.sh` for `print_failure_hint`
- [x] Parse `$1` as `CODE`; if empty or not matching `HPA-30[1-6]` pattern, print usage and `exit 2`
- [x] Extract numeric suffix: `NUM="${CODE#HPA-}"` for use in function routing
- [x] Create `${FIX_DIR}` if it does not exist: `mkdir -p "${FIX_DIR}"`
- [x] Add `case "${CODE}" in` dispatch: `HPA-301)` → `fix_hpa_301`, ..., `HPA-306)` → `fix_hpa_306`
- [x] Default `*` case: print usage message and `exit 2`
- [x] After dispatch, call `print_failure_hint "${NUM}"` to remind user of context
- [x] Print `Next command: ./scripts/up.sh --resume hpa_proof` as final line

### Task 6.2.2 — Implement `log_fix_result` helper
- [x] Define `log_fix_result()` function accepting args: `code`, `status`, `note`
- [x] Write JSON to `${FIX_DIR}/${code}.json`: `{"code":"${code}","status":"${status}","note":"${note}","run_id":"${RUN_ID:-unknown}"}`
- [x] Append human-readable summary line to `${FIX_DIR}/${code}.log`: `[$(date -u +%FT%TZ)] code=${code} status=${status} note=${note}`
- [x] Ensure function does not `exit` on its own — callers decide flow

### Task 6.2.3 — Implement `fix_hpa_301` (Attempt 1): `kubectl apply -f k8s/hpa.yaml` + verify HPA exists
- [x] Define `fix_hpa_301()` function; redirect all output to `${FIX_DIR}/HPA-301.log`
- [x] Run `kubectl apply -f k8s/hpa.yaml -n ${NAMESPACE}` (canonical apply)
- [x] Verify: `kubectl -n ${NAMESPACE} get hpa >/dev/null 2>&1`
- [x] On success: call `log_fix_result "HPA-301" "ok" "HPA applied from k8s/hpa.yaml"`
- [x] On failure: call `log_fix_result "HPA-301" "fail" "kubectl apply returned non-zero"`; return 1

### Task 6.2.4 — Implement `fix_hpa_302` (Attempt 1): apply `metrics-server.yaml` + rollout wait + verify `kubectl top nodes`
- [x] Define `fix_hpa_302()` function; redirect output to `${FIX_DIR}/HPA-302.log`
- [x] Run `kubectl apply -f k8s/addons/metrics-server.yaml`
- [x] Wait: `kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s`
- [x] Verify: `kubectl top nodes >/dev/null 2>&1`
- [x] On success: call `log_fix_result "HPA-302" "ok" "metrics-server applied and rolled out"`
- [x] On failure: call `log_fix_result "HPA-302" "fail" "metrics-server rollout or top nodes failed"`; return 1

### Task 6.2.5 — Implement `fix_hpa_303` (Attempt 1): `kubectl apply -f k8s/deployment.yaml` + rollout + verify CPU request
- [x] Define `fix_hpa_303()` function; redirect output to `${FIX_DIR}/HPA-303.log`
- [x] Run `kubectl apply -f k8s/app/${APP_MODE:-landing}/deployment.yaml -n ${NAMESPACE}`
- [x] Wait: `kubectl -n ${NAMESPACE} rollout status deploy/${APP_DEPLOYMENT} --timeout=180s`
- [x] Verify CPU request set: `kubectl -n ${NAMESPACE} get deploy ${APP_DEPLOYMENT} -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q .`
- [x] On success: call `log_fix_result "HPA-303" "ok" "deployment reapplied with CPU requests"`
- [x] On failure: call `log_fix_result "HPA-303" "fail" "CPU request still missing after apply"`; return 1

### Task 6.2.6 — Implement `fix_hpa_304` (Attempt 1): `load.sh --mode ${LOAD_MODE}` + verify `--status`
- [x] Define `fix_hpa_304()` function; redirect output to `${FIX_DIR}/HPA-304.log`
- [x] Run `./scripts/load.sh --mode "${LOAD_MODE:-pod}"`
- [x] Verify: `./scripts/load.sh --status | grep -q "active"`
- [x] On success: call `log_fix_result "HPA-304" "ok" "load generator started (mode=${LOAD_MODE:-pod})"`
- [x] On failure: call `log_fix_result "HPA-304" "fail" "load generator not active after start attempt"`; return 1

### Task 6.2.7 — Implement `fix_hpa_305` (Attempt 1): apply `k8s/presets/hpa-proof.yaml` + load preset start
- [x] Define `fix_hpa_305()` function; redirect output to `${FIX_DIR}/HPA-305.log`
- [x] Run `kubectl apply -f k8s/presets/hpa-proof.yaml -n ${NAMESPACE}` (demo-safe HPA with low CPU target)
- [x] Start load with preset: `./scripts/load.sh --preset hpa-proof --mode "${LOAD_MODE:-pod}"`
- [x] On success: call `log_fix_result "HPA-305" "ok" "hpa-proof preset applied and load started"`
- [x] On failure: call `log_fix_result "HPA-305" "fail" "preset apply or load start failed"`; return 1

### Task 6.2.8 — Implement `fix_hpa_306` (Attempt 1): `load.sh --stop` + write `HPA_COOLDOWN_SEC=420` env override
- [x] Define `fix_hpa_306()` function; redirect output to `${FIX_DIR}/HPA-306.log`
- [x] Run `./scripts/load.sh --stop` to ensure load is stopped cleanly
- [x] Write env override: `echo "HPA_COOLDOWN_SEC=420" >> .state/env-overrides` (create `.state/` if needed)
- [x] Print message: `Cooldown window extended to 420s. Re-run will use this override.`
- [x] On success: call `log_fix_result "HPA-306" "ok" "load stopped; HPA_COOLDOWN_SEC=420 override written"`
- [x] On failure: call `log_fix_result "HPA-306" "fail" "load stop or override write failed"`; return 1
