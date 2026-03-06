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

### Task 6.2.1 — Create `scripts/fix.sh` entrypoint with `CODE` arg parsing and `case` dispatch
- [ ] Create `scripts/fix.sh` with shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- [ ] Source `scripts/lib/config.sh` to get `NAMESPACE`, `FIX_DIR`, `RUN_ID`, `ARTIFACT_ROOT`
- [ ] Source `scripts/lib/failure-maps.sh` for `print_failure_hint`
- [ ] Parse `$1` as `CODE`; if empty or not matching `HPA-30[1-6]` pattern, print usage and `exit 2`
- [ ] Extract numeric suffix: `NUM="${CODE#HPA-}"` for use in function routing
- [ ] Create `${FIX_DIR}` if it does not exist: `mkdir -p "${FIX_DIR}"`
- [ ] Add `case "${CODE}" in` dispatch: `HPA-301)` → `fix_hpa_301`, ..., `HPA-306)` → `fix_hpa_306`
- [ ] Default `*` case: print usage message and `exit 2`
- [ ] After dispatch, call `print_failure_hint "${NUM}"` to remind user of context
- [ ] Print `Next command: ./scripts/up.sh --resume hpa_proof` as final line

### Task 6.2.2 — Implement `log_fix_result` helper
- [ ] Define `log_fix_result()` function accepting args: `code`, `status`, `note`
- [ ] Write JSON to `${FIX_DIR}/${code}.json`: `{"code":"${code}","status":"${status}","note":"${note}","run_id":"${RUN_ID:-unknown}"}`
- [ ] Append human-readable summary line to `${FIX_DIR}/${code}.log`: `[$(date -u +%FT%TZ)] code=${code} status=${status} note=${note}`
- [ ] Ensure function does not `exit` on its own — callers decide flow

### Task 6.2.3 — Implement `fix_hpa_301` (Attempt 1): `kubectl apply -f k8s/hpa.yaml` + verify HPA exists
- [ ] Define `fix_hpa_301()` function; redirect all output to `${FIX_DIR}/HPA-301.log`
- [ ] Run `kubectl apply -f k8s/hpa.yaml -n ${NAMESPACE}` (canonical apply)
- [ ] Verify: `kubectl -n ${NAMESPACE} get hpa >/dev/null 2>&1`
- [ ] On success: call `log_fix_result "HPA-301" "ok" "HPA applied from k8s/hpa.yaml"`
- [ ] On failure: call `log_fix_result "HPA-301" "fail" "kubectl apply returned non-zero"`; return 1

### Task 6.2.4 — Implement `fix_hpa_302` (Attempt 1): apply `metrics-server.yaml` + rollout wait + verify `kubectl top nodes`
- [ ] Define `fix_hpa_302()` function; redirect output to `${FIX_DIR}/HPA-302.log`
- [ ] Run `kubectl apply -f k8s/addons/metrics-server.yaml`
- [ ] Wait: `kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s`
- [ ] Verify: `kubectl top nodes >/dev/null 2>&1`
- [ ] On success: call `log_fix_result "HPA-302" "ok" "metrics-server applied and rolled out"`
- [ ] On failure: call `log_fix_result "HPA-302" "fail" "metrics-server rollout or top nodes failed"`; return 1

### Task 6.2.5 — Implement `fix_hpa_303` (Attempt 1): `kubectl apply -f k8s/deployment.yaml` + rollout + verify CPU request
- [ ] Define `fix_hpa_303()` function; redirect output to `${FIX_DIR}/HPA-303.log`
- [ ] Run `kubectl apply -f k8s/app/${APP_MODE:-landing}/deployment.yaml -n ${NAMESPACE}`
- [ ] Wait: `kubectl -n ${NAMESPACE} rollout status deploy/${APP_DEPLOYMENT} --timeout=180s`
- [ ] Verify CPU request set: `kubectl -n ${NAMESPACE} get deploy ${APP_DEPLOYMENT} -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q .`
- [ ] On success: call `log_fix_result "HPA-303" "ok" "deployment reapplied with CPU requests"`
- [ ] On failure: call `log_fix_result "HPA-303" "fail" "CPU request still missing after apply"`; return 1

### Task 6.2.6 — Implement `fix_hpa_304` (Attempt 1): `load.sh --mode ${LOAD_MODE}` + verify `--status`
- [ ] Define `fix_hpa_304()` function; redirect output to `${FIX_DIR}/HPA-304.log`
- [ ] Run `./scripts/load.sh --mode "${LOAD_MODE:-pod}"`
- [ ] Verify: `./scripts/load.sh --status | grep -q "active"`
- [ ] On success: call `log_fix_result "HPA-304" "ok" "load generator started (mode=${LOAD_MODE:-pod})"`
- [ ] On failure: call `log_fix_result "HPA-304" "fail" "load generator not active after start attempt"`; return 1

### Task 6.2.7 — Implement `fix_hpa_305` (Attempt 1): apply `k8s/presets/hpa-proof.yaml` + load preset start
- [ ] Define `fix_hpa_305()` function; redirect output to `${FIX_DIR}/HPA-305.log`
- [ ] Run `kubectl apply -f k8s/presets/hpa-proof.yaml -n ${NAMESPACE}` (demo-safe HPA with low CPU target)
- [ ] Start load with preset: `./scripts/load.sh --preset hpa-proof --mode "${LOAD_MODE:-pod}"`
- [ ] On success: call `log_fix_result "HPA-305" "ok" "hpa-proof preset applied and load started"`
- [ ] On failure: call `log_fix_result "HPA-305" "fail" "preset apply or load start failed"`; return 1

### Task 6.2.8 — Implement `fix_hpa_306` (Attempt 1): `load.sh --stop` + write `HPA_COOLDOWN_SEC=420` env override
- [ ] Define `fix_hpa_306()` function; redirect output to `${FIX_DIR}/HPA-306.log`
- [ ] Run `./scripts/load.sh --stop` to ensure load is stopped cleanly
- [ ] Write env override: `echo "HPA_COOLDOWN_SEC=420" >> .state/env-overrides` (create `.state/` if needed)
- [ ] Print message: `Cooldown window extended to 420s. Re-run will use this override.`
- [ ] On success: call `log_fix_result "HPA-306" "ok" "load stopped; HPA_COOLDOWN_SEC=420 override written"`
- [ ] On failure: call `log_fix_result "HPA-306" "fail" "load stop or override write failed"`; return 1
