# Implementation Spec: Local Kubernetes Autoscaling Lab

## Scope

- Target: laptop/PC local environment with KinD
- Toolchain: `bash`, `node`, `docker`, `kind`
- Primary behavior: deterministic setup, validation, recovery, and teardown
- Core objective: prove autoscaling behavior under synthetic load with browser-accessible service

---

## Execution Matrices

### Primary Gate Matrix

| Order | Gate | Severity | Pass Condition | On Fail |
|---|---|---|---|---|
| 1 | Bootstrap | CRITICAL | Cluster + namespace + workloads + metrics baseline ready | Exit fast with mapped fix command |
| 2 | Reachability | CRITICAL | NodePort path/browser HTTP smoke succeeds | Exit fast with mapped fix command |
| 3 | HPA Proof | CRITICAL | Scale-up above baseline under load (plus cooldown signal) | Exit fast with mapped fix command |
| 4 | Evidence Capture | NON_CRITICAL | Output + screenshot/GIF + checklist artifacts present | Continue, warn, and suggest evidence command |
| 5 | Teardown Integrity | NON_CRITICAL | Cleanup completes and re-run remains possible | Continue, summarize warnings |

### Resume Matrix (`up.sh --resume hpa_proof`)

| Step | Gate | Purpose |
|---|---|---|
| 1 | bootstrap_integrity | Confirm cluster/app state still valid (no recreate) |
| 2 | reachability_gate | Ensure service/browser path still works |
| 3 | hpa_proof | Re-run autoscaling proof deterministically |
| 4 | evidence_capture | Refresh artifacts/checklist state |

### Outcome Decision Matrix

| Condition | Overall Status | Deterministic Next Command |
|---|---|---|
| Any critical gate failed | `BLOCKED_CRITICAL_FAILURE` | `./scripts/fix.sh HPA-30X` via code map |
| No critical failures, evidence failed | `LEARNING_READY_WITH_WARNINGS_(FULL/RESUME)` | `./scripts/collect-evidence.sh ...` |
| All required gates passed | `SUCCESS_(FULL/RESUME)` | `./scripts/down.sh ...` |

---

## HPA Failure Routing

### Code Map

| Code | Meaning |
|---|---|
| 301 | HPA object missing |
| 302 | Metrics unavailable |
| 303 | Resource requests missing |
| 304 | Load generator failed to start |
| 305 | No scale-up observed within ramp window |
| 306 | Cooldown scale-down not observed within window |

### Deterministic Next Command Map

| Code | Next Command |
|---|---|
| 301 | `./scripts/fix.sh HPA-301` |
| 302 | `./scripts/fix.sh HPA-302` |
| 303 | `./scripts/fix.sh HPA-303` |
| 304 | `./scripts/fix.sh HPA-304` |
| 305 | `./scripts/fix.sh HPA-305` |
| 306 | `./scripts/fix.sh HPA-306` |

### 3-Attempt Variant Matrix (`HPA-301..306`)

| Code | Attempt 1 (Canonical) | Attempt 2 (Tuned) | Attempt 3 (Fallback) | Verify Pass Condition | Timeout (A1/A2/A3) |
|---|---|---|---|---|---|
| HPA-301 | Apply canonical HPA manifest | Server-side re-apply + target ref tune | Delete/recreate from known-good preset | `kubectl -n $NS get hpa $HPA` succeeds and target deployment matches | `60/90/120s` |
| HPA-302 | Apply metrics-server + wait | Restart with KinD-tuned args | Recreate from pinned local KinD manifest | `kubectl top nodes` succeeds and metrics-server deployment ready | `120/180/240s` |
| HPA-303 | Re-apply deployment with requests | Patch CPU/memory requests directly | Apply tiny-safe fallback deployment preset | CPU request exists and rollout complete | `90/120/180s` |
| HPA-304 | Start configured load mode | Deterministic mode switch (`pod<->host`) | Start fallback low internal load profile | `./scripts/load.sh --status` reports active | `60/90/120s` |
| HPA-305 | Apply proof preset + rerun load | Increase load + extend ramp | Lower HPA target (demo-safe) + host-load fallback | `max_replicas_seen > baseline` in ramp window | `180/240/300s` |
| HPA-306 | Stop load + observe longer | Patch `behavior.scaleDown` + observe | Enforce zero-load + extended observation | observed replicas `< max_seen` in cooldown window | `240/300/420s` |

---

## Generated Bash Pseudocode

### `run_gate`

```bash
# run_gate <gate_name> <severity> <function_name>
run_gate() {
  local gate_name="$1"
  local severity="$2"   # CRITICAL | NON_CRITICAL
  local fn="$3"

  local start_ts end_ts dur_ms rc status
  local gate_log="${GATE_DIR}/${gate_name}.log"
  local gate_json="${GATE_DIR}/${gate_name}.json"

  start_ts="$(date -u +%FT%TZ)"
  : > "${gate_log}"

  "${fn}" >"${gate_log}" 2>&1
  rc=$?

  if [ "${rc}" -eq 0 ]; then status="PASS"; else status="FAIL"; fi

  end_ts="$(date -u +%FT%TZ)"
  dur_ms="$(duration_ms "${start_ts}" "${end_ts}")"

  cat > "${gate_json}" <<EOF
{
  "gate": "${gate_name}",
  "severity": "${severity}",
  "status": "${status}",
  "exit_code": ${rc},
  "started_at": "${start_ts}",
  "ended_at": "${end_ts}",
  "duration_ms": ${dur_ms},
  "log_file": "${gate_log}"
}
EOF

  printf '{"gate":"%s","severity":"%s","status":"%s","exit_code":%s}\n' \
    "${gate_name}" "${severity}" "${status}" "${rc}" >> "${SCORECARD_FILE}"

  if [ "${rc}" -ne 0 ] && [ "${severity}" = "CRITICAL" ]; then
    print_failure_hint "${rc}"
    print_next_command_for_code "${rc}"
    exit "${rc}"
  fi

  if [ "${rc}" -ne 0 ] && [ "${severity}" = "NON_CRITICAL" ]; then
    warn "NON_CRITICAL gate failed: ${gate_name} (code ${rc})"
    return 0
  fi

  return 0
}
```

### `gate_hpa_proof`

```bash
gate_hpa_proof() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local hpa="${HPA_NAME:-sample-app-hpa}"
  local load_mode="${LOAD_MODE:-pod}"
  local ramp_sec="${HPA_RAMP_SEC:-180}"
  local cool_sec="${HPA_COOLDOWN_SEC:-240}"
  local poll_sec="${HPA_POLL_SEC:-10}"

  local baseline current max_seen
  local hpa_desc="${HPA_DIR}/hpa_describe.txt"
  local hpa_yaml="${HPA_DIR}/hpa.yaml"
  local top_nodes="${HPA_DIR}/top_nodes.txt"
  local top_pods="${HPA_DIR}/top_pods.txt"
  local samples_csv="${HPA_DIR}/replica_samples.csv"
  local summary_txt="${HPA_DIR}/summary.txt"

  kubectl -n "${ns}" get hpa "${hpa}" >/dev/null 2>&1 || return 301
  kubectl top nodes > "${top_nodes}" 2>/dev/null || return 302
  kubectl -n "${ns}" top pods > "${top_pods}" 2>/dev/null || return 302

  kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q . || return 303

  baseline="$(kubectl -n "${ns}" get deploy "${deploy}" -o jsonpath='{.status.replicas}')"
  [ -n "${baseline}" ] || baseline=1
  max_seen="${baseline}"

  kubectl -n "${ns}" describe hpa "${hpa}" > "${hpa_desc}" 2>/dev/null || true
  kubectl -n "${ns}" get hpa "${hpa}" -o yaml > "${hpa_yaml}" 2>/dev/null || true
  echo "ts,replicas" > "${samples_csv}"

  start_load "${load_mode}" "${ns}" "${deploy}" || return 304

  local elapsed=0
  while [ "${elapsed}" -lt "${ramp_sec}" ]; do
    current="$(kubectl -n "${ns}" get deploy "${deploy}" -o jsonpath='{.status.replicas}')"
    [ -n "${current}" ] || current=0
    printf "%s,%s\n" "$(date -u +%FT%TZ)" "${current}" >> "${samples_csv}"
    if [ "${current}" -gt "${max_seen}" ]; then max_seen="${current}"; fi
    sleep "${poll_sec}"
    elapsed=$((elapsed + poll_sec))
  done

  if [ "${max_seen}" -le "${baseline}" ]; then
    stop_load "${load_mode}" || true
    return 305
  fi

  stop_load "${load_mode}" || true
  elapsed=0
  local cooled=0
  while [ "${elapsed}" -lt "${cool_sec}" ]; do
    current="$(kubectl -n "${ns}" get deploy "${deploy}" -o jsonpath='{.status.replicas}')"
    [ -n "${current}" ] || current=0
    printf "%s,%s\n" "$(date -u +%FT%TZ)" "${current}" >> "${samples_csv}"
    if [ "${current}" -lt "${max_seen}" ]; then cooled=1; break; fi
    sleep "${poll_sec}"
    elapsed=$((elapsed + poll_sec))
  done

  if [ "${cooled}" -ne 1 ]; then
    cat > "${summary_txt}" <<EOF
HPA scale-up proved (baseline=${baseline}, max_seen=${max_seen})
Cooldown not observed within ${cool_sec}s
EOF
    return 306
  fi

  cat > "${summary_txt}" <<EOF
PASS
baseline_replicas=${baseline}
max_replicas_seen=${max_seen}
scale_up_window_sec=${ramp_sec}
cooldown_window_sec=${cool_sec}
samples_file=${samples_csv}
EOF

  return 0
}
```

### `print_failure_hint`

```bash
print_failure_hint() {
  local code="$1"
  case "${code}" in
    301)
      cat <<'EOF'
[HPA-301] HPA object missing.
Check: kubectl -n autoscaling-lab get hpa
Fix:   kubectl -n autoscaling-lab apply -f k8s/hpa.yaml
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    302)
      cat <<'EOF'
[HPA-302] Metrics unavailable.
Check: kubectl top nodes
Fix:   ./scripts/fix.sh HPA-302
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    303)
      cat <<'EOF'
[HPA-303] Resource requests missing.
Check: kubectl -n autoscaling-lab get deploy sample-app -o yaml
Fix:   ./scripts/fix.sh HPA-303
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    304)
      cat <<'EOF'
[HPA-304] Load generator failed to start.
Check: ./scripts/load.sh --status
Fix:   ./scripts/fix.sh HPA-304
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    305)
      cat <<'EOF'
[HPA-305] No scale-up observed.
Check: kubectl -n autoscaling-lab describe hpa sample-app-hpa
Fix:   ./scripts/fix.sh HPA-305
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    306)
      cat <<'EOF'
[HPA-306] Cooldown not observed.
Check: kubectl -n autoscaling-lab describe hpa sample-app-hpa
Fix:   ./scripts/fix.sh HPA-306
Retry: ./scripts/up.sh --resume hpa_proof
EOF
      ;;
    *)
      echo "[GENERIC-${code}] Unknown failure code."
      ;;
  esac
}
```

### `print_next_command_for_code`

```bash
print_next_command_for_code() {
  local code="$1"
  case "${code}" in
    301) echo "./scripts/fix.sh HPA-301" ;;
    302) echo "./scripts/fix.sh HPA-302" ;;
    303) echo "./scripts/fix.sh HPA-303" ;;
    304) echo "./scripts/fix.sh HPA-304" ;;
    305) echo "./scripts/fix.sh HPA-305" ;;
    306) echo "./scripts/fix.sh HPA-306" ;;
    *)   echo "./scripts/fix.sh GENERIC-${code}" ;;
  esac
}
```

### `fix.sh` Dispatcher

```bash
#!/usr/bin/env bash
set -euo pipefail

CODE="${1:-}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
ARTIFACT_ROOT="artifacts/${RUN_ID}"
FIX_DIR="${ARTIFACT_ROOT}/fixes"
NS="${NAMESPACE:-autoscaling-lab}"

mkdir -p "${FIX_DIR}"

usage() {
  echo "Usage: ./scripts/fix.sh HPA-301|HPA-302|HPA-303|HPA-304|HPA-305|HPA-306"
  exit 2
}

log_fix_result() {
  local code="$1" status="$2" note="$3"
  cat > "${FIX_DIR}/${code}.json" <<EOF
{"code":"${code}","status":"${status}","note":"${note}","run_id":"${RUN_ID}"}
EOF
}

fix_hpa_301() {
  kubectl -n "${NS}" apply -f k8s/hpa.yaml > "${FIX_DIR}/HPA-301.log" 2>&1
  kubectl -n "${NS}" get hpa sample-app-hpa >> "${FIX_DIR}/HPA-301.log" 2>&1
  log_fix_result "HPA-301" "PASS" "HPA resource applied and verified"
}

fix_hpa_302() {
  kubectl apply -f k8s/addons/metrics-server.yaml > "${FIX_DIR}/HPA-302.log" 2>&1
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s >> "${FIX_DIR}/HPA-302.log" 2>&1
  kubectl top nodes >> "${FIX_DIR}/HPA-302.log" 2>&1
  log_fix_result "HPA-302" "PASS" "Metrics server ready and top nodes succeeds"
}

fix_hpa_303() {
  kubectl -n "${NS}" apply -f k8s/deployment.yaml > "${FIX_DIR}/HPA-303.log" 2>&1
  kubectl -n "${NS}" rollout status deploy/sample-app --timeout=180s >> "${FIX_DIR}/HPA-303.log" 2>&1
  kubectl -n "${NS}" get deploy sample-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' >> "${FIX_DIR}/HPA-303.log" 2>&1
  log_fix_result "HPA-303" "PASS" "Deployment requests restored and rollout healthy"
}

fix_hpa_304() {
  ./scripts/load.sh --mode "${LOAD_MODE:-pod}" > "${FIX_DIR}/HPA-304.log" 2>&1
  ./scripts/load.sh --status >> "${FIX_DIR}/HPA-304.log" 2>&1
  log_fix_result "HPA-304" "PASS" "Load generator started and status verified"
}

fix_hpa_305() {
  kubectl -n "${NS}" apply -f k8s/presets/hpa-proof.yaml > "${FIX_DIR}/HPA-305.log" 2>&1
  ./scripts/load.sh --mode "${LOAD_MODE:-pod}" --preset hpa-proof >> "${FIX_DIR}/HPA-305.log" 2>&1
  log_fix_result "HPA-305" "PASS" "HPA proof preset applied and load preset started"
}

fix_hpa_306() {
  ./scripts/load.sh --stop > "${FIX_DIR}/HPA-306.log" 2>&1
  echo "HPA_COOLDOWN_SEC=420" > "${FIX_DIR}/HPA-306.env"
  log_fix_result "HPA-306" "PASS" "Load stopped and cooldown extension prepared"
}

main() {
  [ -n "${CODE}" ] || usage
  case "${CODE}" in
    HPA-301) fix_hpa_301 ;;
    HPA-302) fix_hpa_302 ;;
    HPA-303) fix_hpa_303 ;;
    HPA-304) fix_hpa_304 ;;
    HPA-305) fix_hpa_305 ;;
    HPA-306) fix_hpa_306 ;;
    *) usage ;;
  esac
  echo "Fix complete for ${CODE}"
  echo "Artifacts: ${FIX_DIR}/"
  echo "Next command: ./scripts/up.sh --resume hpa_proof"
}

main "$@"
```

### `up.sh --resume hpa_proof`

```bash
#!/usr/bin/env bash
set -euo pipefail

RESUME_TARGET=""
RUN_ID_ARG=""
PROFILE="${PROFILE:-tiny}"
APP_MODE="${APP_MODE:-landing}"
LOAD_MODE="${LOAD_MODE:-pod}"

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --resume) RESUME_TARGET="${2:-}"; shift 2 ;;
      --run-id) RUN_ID_ARG="${2:-}"; shift 2 ;;
      --profile) PROFILE="${2:-}"; shift 2 ;;
      --app-mode) APP_MODE="${2:-}"; shift 2 ;;
      --load-mode) LOAD_MODE="${2:-}"; shift 2 ;;
      *) echo "Unknown arg: $1"; exit 2 ;;
    esac
  done
}

resolve_run_id() {
  if [ -n "${RUN_ID_ARG}" ]; then
    RUN_ID="${RUN_ID_ARG}"
  elif [ -n "${RESUME_TARGET}" ] && [ -f ".state/last_run_id" ]; then
    RUN_ID="$(cat .state/last_run_id)"
  else
    RUN_ID="$(date +%Y%m%d-%H%M%S)"
  fi
  export RUN_ID
  export ARTIFACT_ROOT="artifacts/${RUN_ID}"
  export SCORECARD_FILE="${ARTIFACT_ROOT}/scorecard.jsonl"
  mkdir -p "${ARTIFACT_ROOT}" ".state"
  echo "${RUN_ID}" > .state/last_run_id
}

run_sequence() {
  local sequence_name="$1"; shift
  local gates=("$@")
  echo "Running sequence: ${sequence_name}" | tee -a "${ARTIFACT_ROOT}/timeline.log"
  for g in "${gates[@]}"; do
    case "${g}" in
      bootstrap_gate)      run_gate "bootstrap_gate" "CRITICAL" "gate_bootstrap" ;;
      bootstrap_integrity) run_gate "bootstrap_integrity" "CRITICAL" "gate_bootstrap_integrity" ;;
      reachability_gate)   run_gate "reachability_gate" "CRITICAL" "gate_reachability" ;;
      hpa_proof)           run_gate "hpa_proof" "CRITICAL" "gate_hpa_proof" ;;
      evidence_capture)    run_gate "evidence_capture" "NON_CRITICAL" "gate_evidence_capture" ;;
      *) echo "Unknown gate in sequence: ${g}"; exit 112 ;;
    esac
  done
}

resume_hpa_proof_run() {
  run_sequence "resume_hpa_proof" \
    "bootstrap_integrity" \
    "reachability_gate" \
    "hpa_proof" \
    "evidence_capture"
}

main() {
  parse_args "$@"
  resolve_run_id
  init_artifacts
  if [ -n "${RESUME_TARGET}" ] && [ "${RESUME_TARGET}" = "hpa_proof" ]; then
    resume_hpa_proof_run
  else
    run_sequence "full_run" "bootstrap_gate" "reachability_gate" "hpa_proof" "evidence_capture"
  fi
  print_final_scorecard
  print_next_action_from_scorecard
}

main "$@"
```

### `print_next_action_from_scorecard` (Node-backed)

```bash
print_next_action_from_scorecard() {
  local mode="full_run"
  [ -n "${RESUME_TARGET:-}" ] && mode="resume"

  local resolution
  resolution="$(node - "${SCORECARD_FILE}" "${mode}" "${RUN_ID}" "${RESUME_TARGET:-}" <<'NODE'
const fs = require('fs');
const scoreFile = process.argv[2];
const mode = process.argv[3];
const runId = process.argv[4];
const resumeTarget = process.argv[5] || '';

function out(k,v){ process.stdout.write(`${k}=${v}\n`); }

let rows = [];
try { rows = fs.readFileSync(scoreFile,'utf8').split('\n').filter(Boolean).map(JSON.parse); }
catch {
  out('NEXT_TYPE','CMD');
  out('NEXT_CMD',`./scripts/validate.sh --run-id ${runId}`);
  out('OVERALL_STATUS','UNKNOWN_NO_SCORECARD');
  process.exit(0);
}

const priority = ['bootstrap_gate','bootstrap_integrity','reachability_gate','hpa_proof'];
const byGate = new Map();
for (const r of rows) byGate.set(r.gate, r);

let failed = null;
for (const g of priority) {
  const r = byGate.get(g);
  if (r && r.severity === 'CRITICAL' && r.status === 'FAIL') { failed = r; break; }
}

if (failed) {
  out('NEXT_TYPE','FIX');
  out('EXIT_CODE', String(failed.exit_code ?? 999));
  out('OVERALL_STATUS','BLOCKED_CRITICAL_FAILURE');
  process.exit(0);
}

const evidence = byGate.get('evidence_capture');
const evidenceFailed = !!(evidence && evidence.severity === 'NON_CRITICAL' && evidence.status === 'FAIL');

if (evidenceFailed) {
  out('NEXT_TYPE','CMD');
  if (mode === 'resume') {
    out('NEXT_CMD', `./scripts/collect-evidence.sh --run-id ${runId} --from-resume ${resumeTarget || 'unknown'}`);
    out('OVERALL_STATUS','LEARNING_READY_WITH_WARNINGS_RESUME');
  } else {
    out('NEXT_CMD', `./scripts/collect-evidence.sh --run-id ${runId}`);
    out('OVERALL_STATUS','LEARNING_READY_WITH_WARNINGS_FULL');
  }
  process.exit(0);
}

out('NEXT_TYPE','CMD');
if (mode === 'resume') {
  out('NEXT_CMD', `./scripts/down.sh --run-id ${runId} --preserve-artifacts`);
  out('OVERALL_STATUS','SUCCESS_RESUME');
} else {
  out('NEXT_CMD', `./scripts/down.sh --run-id ${runId}`);
  out('OVERALL_STATUS','SUCCESS_FULL');
}
NODE
)"

  local NEXT_TYPE="" NEXT_CMD="" EXIT_CODE="" OVERALL_STATUS=""
  while IFS='=' read -r k v; do
    case "${k}" in
      NEXT_TYPE) NEXT_TYPE="${v}" ;;
      NEXT_CMD) NEXT_CMD="${v}" ;;
      EXIT_CODE) EXIT_CODE="${v}" ;;
      OVERALL_STATUS) OVERALL_STATUS="${v}" ;;
    esac
  done <<< "${resolution}"

  local final_cmd=""
  if [ "${NEXT_TYPE}" = "FIX" ]; then
    final_cmd="$(print_next_command_for_code "${EXIT_CODE}")"
  else
    final_cmd="${NEXT_CMD}"
  fi

  echo "Overall status: ${OVERALL_STATUS}"
  echo "Next command: ${final_cmd}"
}
```

### `print_final_scorecard`

```bash
print_final_scorecard() {
  local outcome_json
  outcome_json="$(resolve_run_outcome)"

  local overall_status mode crit_p crit_t non_p non_t failed_gate failed_code next_cmd
  overall_status="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.overall_status)' "${outcome_json}")"
  mode="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.mode)' "${outcome_json}")"
  crit_p="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.critical_passed)' "${outcome_json}")"
  crit_t="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.critical_total)' "${outcome_json}")"
  non_p="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.noncritical_passed)' "${outcome_json}")"
  non_t="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.noncritical_total)' "${outcome_json}")"
  failed_gate="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.failed_gate||"")' "${outcome_json}")"
  failed_code="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.failed_code||"")' "${outcome_json}")"
  next_cmd="$(node -e 'const o=JSON.parse(process.argv[1]);console.log(o.next_command)' "${outcome_json}")"

  if [[ "${next_cmd}" == __FIX_BY_CODE__:* ]]; then
    next_cmd="$(print_next_command_for_code "${next_cmd#__FIX_BY_CODE__:}")"
  fi

  echo "=== Autoscaling Lab Scorecard ==="
  echo "RUN_ID: ${RUN_ID}"
  echo "MODE: ${mode}"
  echo "Critical gates: ${crit_p}/${crit_t} passed"
  echo "Non-critical gates: ${non_p}/${non_t} passed"
  [ -n "${failed_gate}" ] && echo "First critical failure: ${failed_gate} (code ${failed_code})"
  echo "Overall status: ${overall_status}"
  echo "Next command: ${next_cmd}"

  cat > "${ARTIFACT_ROOT}/final_scorecard.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "mode": "${mode}",
  "overall_status": "${overall_status}",
  "critical_passed": ${crit_p},
  "critical_total": ${crit_t},
  "noncritical_passed": ${non_p},
  "noncritical_total": ${non_t},
  "failed_gate": "${failed_gate}",
  "failed_code": "${failed_code}",
  "next_command": "${next_cmd}"
}
EOF
}
```

---

## Consolidated Implementation Solutions

- **Solution A:** deterministic gate engine with severity-aware branching
- **Solution B:** HPA proof loop with bounded remediation (`301-306`, 3 attempts)
- **Solution C:** Node-based single outcome resolver for status + next action
- **Solution D:** deterministic resume flow (`up.sh --resume hpa_proof`)
- **Solution E:** evidence-first learner flow and artifact contracts
