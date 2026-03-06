# Epics, Stories & Tasks
## Local Kubernetes Autoscaling Lab

**Version:** 1.0
**Date:** 2026-03-06
**Derived from:** `_bmad-output/product-brief.md`

---

## Epic Index

| # | Epic | Priority | Stories | Tasks |
|---|---|---|---|---|
| E1 | Project Scaffold & Configuration Surface | P1 | 2 | 8 |
| E2 | Deterministic Gate Engine | P1 | 2 | 10 |
| E3 | Unified Outcome Resolver | P1 | 2 | 11 |
| E4 | Bootstrap & Reachability Gates | P2 | 2 | 10 |
| E5 | HPA Proof Gate | P2 | 2 | 9 |
| E6 | HPA Failure Codes & Fix Dispatcher | P2 | 3 | 18 |
| E7 | Resume Path | P2 | 1 | 5 |
| E8 | D3 Delivery Model — App & Load Modes | P3 | 3 | 14 |
| E9 | Evidence Capture & Teardown | P3 | 2 | 7 |
| E10 | Documentation & Learner Experience | P3 | 2 | 7 |
| | **Total** | | **21** | **99** |

---

> All epics are derived from `product-brief.md`. Section references use brief section numbers at time of authoring.

## Implementation Order

```
E1 (scaffold + config)
  ↓
E2 (gate engine) → E3 (outcome resolver)
  ↓
E4 (bootstrap + reachability) → E5 (HPA proof gate) → E6 (failure codes + fix dispatcher)
  ↓
E7 (resume path)
  ↓
E8 (D3 app + load modes)
  ↓
E9 (evidence + teardown) → E10 (docs)
```

---

## EPIC 1 — Project Scaffold & Configuration Surface

**Goal:** Establish the project structure, toolchain contract, and environment variable configuration surface that all other epics build on.

---

### Story 1.1 — Project Directory Structure

**As a** contributor,
**I want** a standard, documented project layout,
**so that** every script, manifest, and artifact has a predictable location.

**Acceptance Criteria:**
- `scripts/`, `scripts/lib/`, `k8s/`, `k8s/addons/`, `k8s/presets/`, `k8s/app/landing/`, `k8s/app/api/`, `docs/`, `artifacts/`, `.state/` directories exist or are created on first run
- `README.md` documents top-level layout
- `.gitignore` excludes `artifacts/` and `.state/`

| Task | Description |
|---|---|
| 1.1.1 | Create directory skeleton: `scripts/lib/`, `k8s/app/landing/`, `k8s/app/api/`, `k8s/addons/`, `k8s/presets/`, `docs/` |
| 1.1.2 | Add `.gitignore` entries for `artifacts/`, `.state/`, `*.log` |
| 1.1.3 | Create `README.md` with project overview, prerequisites, and top-level command reference |

---

### Story 1.2 — Configuration Surface (`config.sh`)

**As a** lab user,
**I want** a single configuration file that defines all environment variables with documented defaults,
**so that** I can control `APP_MODE`, `LOAD_MODE`, and `PROFILE` without editing scripts.

**Acceptance Criteria:**
- `scripts/lib/config.sh` exports: `APP_MODE` (default: `landing`), `LOAD_MODE` (default: `pod`), `PROFILE` (default: `tiny`), `NAMESPACE` (default: `autoscaling-lab`), `APP_DEPLOYMENT`, `HPA_NAME`, timing vars (`HPA_RAMP_SEC`, `HPA_COOLDOWN_SEC`, `HPA_POLL_SEC`)
- Profile → maxReplicas lookup returns: `tiny=5`, `balanced=7`, `stretch=10`
- Profile admission guard: warn if `balanced` and < 4GB available; block if `stretch` and < 8GB available
- All variables respect pre-set environment (i.e., `${VAR:-default}` pattern)

| Task | Description |
|---|---|
| 1.2.1 | Create `scripts/lib/config.sh` with all env var defaults |
| 1.2.2 | Implement `get_max_replicas` function: `case $PROFILE in tiny) echo 5;; balanced) echo 7;; stretch) echo 10;; esac` |
| 1.2.3 | Implement `profile_admission_guard`: check `free -m` (Linux) / `vm_stat` (macOS) against profile thresholds |
| 1.2.4 | Implement cross-OS memory check helper with graceful degradation if command unavailable |
| 1.2.5 | Document all env vars in `docs/configuration.md` with default values and allowed values |

---

## EPIC 2 — Deterministic Gate Engine

**Goal:** Implement the `run_gate` orchestration wrapper and `run_sequence` dispatcher that all gates flow through, with severity-aware branching, per-gate artifacts, and scorecard JSONL.

---

### Story 2.1 — `run_gate` Framework

**As a** gate author,
**I want** a reusable `run_gate <name> <severity> <fn>` function,
**so that** every gate gets automatic timing, logging, artifact generation, and correct severity routing without duplicating that logic.

**Acceptance Criteria:**
- Executes `<fn>` and captures stdout/stderr to `${GATE_DIR}/<name>.log`
- Writes `${GATE_DIR}/<name>.json`: gate, severity, status (PASS/FAIL), exit_code, started_at, ended_at, duration_ms, log_file
- Appends one JSONL line to `${SCORECARD_FILE}` per gate
- CRITICAL failure: calls `print_failure_hint <code>` + `print_next_command_for_code <code>` + exits with gate exit code
- NON_CRITICAL failure: emits warn line, returns 0, pipeline continues

| Task | Description |
|---|---|
| 2.1.1 | Create `scripts/lib/gate-runner.sh` — implement `run_gate` function |
| 2.1.2 | Implement `duration_ms` helper using `date -u +%s%3N` (Linux) with macOS fallback |
| 2.1.3 | Implement per-gate JSON artifact writer (all required fields) |
| 2.1.4 | Implement JSONL scorecard append |
| 2.1.5 | Implement severity-aware exit routing (CRITICAL → exit; NON_CRITICAL → warn+return 0) |

---

### Story 2.2 — Run Sequence & Artifact Initialization

**As a** lab runner,
**I want** a `run_sequence <name> <gates...>` dispatcher and artifact directory initialization,
**so that** full-run and resume sequences share the same routing logic and every run has an isolated artifact directory.

**Acceptance Criteria:**
- `resolve_run_id` sets `RUN_ID`, `ARTIFACT_ROOT`, `SCORECARD_FILE`, `GATE_DIR`; persists `RUN_ID` to `.state/last_run_id`
- `init_artifacts` creates `${ARTIFACT_ROOT}`, `${GATE_DIR}`, `${HPA_DIR}`, `.state/`
- `run_sequence <name> <gate_names...>` routes each gate name to correct `run_gate` call
- Logs sequence start to `${ARTIFACT_ROOT}/timeline.log`

| Task | Description |
|---|---|
| 2.2.1 | Implement `resolve_run_id` in `scripts/lib/run-context.sh` |
| 2.2.2 | Implement `init_artifacts` — create all artifact subdirectories |
| 2.2.3 | Implement `run_sequence` dispatcher with `case` statement routing gate names to gate functions |
| 2.2.4 | Implement `timeline.log` append on sequence start and each gate completion |
| 2.2.5 | Create `scripts/up.sh` entrypoint: parse args → `resolve_run_id` → `init_artifacts` → `run_sequence` → scorecard |

---

## EPIC 3 — Unified Outcome Resolver

**Goal:** Implement a single Node.js-backed resolver that is the sole authority for `overall_status` and `next_command`, consumed by both the printed scorecard and the final JSON artifact.

---

### Story 3.1 — Node Outcome Resolver

**As a** lab runner,
**I want** a Node.js module that reads `scorecard.jsonl` and deterministically computes outcome and next action,
**so that** the scorecard and next_command output can never diverge.

**Acceptance Criteria:**
- Reads `scorecard.jsonl`; handles missing/corrupt file → status `UNKNOWN_NO_SCORECARD`, next: `./scripts/validate.sh --run-id <id>`
- Evaluates CRITICAL gates in fixed priority: `bootstrap_gate → bootstrap_integrity → reachability_gate → hpa_proof`
- First CRITICAL FAIL → `BLOCKED_CRITICAL_FAILURE`; emits `NEXT_TYPE=FIX`, `EXIT_CODE=<n>`
- Evidence NON_CRITICAL FAIL → `LEARNING_READY_WITH_WARNINGS_FULL` or `_RESUME`
- All gates pass → `SUCCESS_FULL` or `SUCCESS_RESUME`
- Differentiates `full_run` vs `resume` mode via argv
- Writes `outcome.json` to `${ARTIFACT_ROOT}/`

| Task | Description |
|---|---|
| 3.1.1 | Create `scripts/lib/outcome-resolver.js` as an inline Node script (stdin-passable) |
| 3.1.2 | Implement gate priority evaluation: fixed array, `Map` lookup, first-CRITICAL-fail detection |
| 3.1.3 | Implement `LEARNING_READY_WITH_WARNINGS` branch with `FULL` vs `RESUME` mode distinction |
| 3.1.4 | Implement `SUCCESS_FULL` / `SUCCESS_RESUME` branch with correct `down.sh` variant |
| 3.1.5 | Implement tamper-tolerant scorecard parsing (try/catch per line; skip malformed) |

---

### Story 3.2 — Scorecard Print Functions

**As a** lab user,
**I want** a human-readable scorecard printed at the end of every run,
**so that** I always know what passed, what failed, and exactly what to do next.

**Acceptance Criteria:**
- `print_final_scorecard` prints: RUN_ID, MODE, critical N/total, non-critical N/total, first critical failure gate+code, overall status, next command
- `print_next_action_from_scorecard` calls outcome-resolver and parses key=value output
- `__FIX_BY_CODE__:<code>` sentinel in `next_command` is translated via `print_next_command_for_code`
- `final_scorecard.json` written to `${ARTIFACT_ROOT}/`
- Fixture tests confirm deterministic output for 3 canonical scorecard states

| Task | Description |
|---|---|
| 3.2.1 | Create `scripts/lib/scorecard.sh` — implement `print_final_scorecard` |
| 3.2.2 | Implement `print_next_action_from_scorecard` backed by Node resolver |
| 3.2.3 | Implement `__FIX_BY_CODE__` sentinel handling |
| 3.2.4 | Write `final_scorecard.json` artifact |
| 3.2.5 | Create `tests/resolver-fixtures/` with 3 JSONL fixture files + expected output assertions |
| 3.2.6 | Create `scripts/test-resolver.sh` — runs fixture tests and reports pass/fail |

---

## EPIC 4 — Bootstrap & Reachability Gates

**Goal:** Implement the first two gates — cluster provisioning and browser reachability — both idempotent and cross-OS.

---

### Story 4.1 — Bootstrap Gate

**As a** lab runner,
**I want** a bootstrap gate that provisions the full cluster stack idempotently,
**so that** the lab reaches a known-good state before any autoscaling test begins.

**Acceptance Criteria:**
- Creates KinD cluster only if it does not already exist (`kind get clusters` check)
- Creates namespace `autoscaling-lab` (idempotent: `--dry-run=client -o yaml | kubectl apply -f -` or `kubectl create ns ... --ignore-not-found`)
- Applies `k8s/addons/metrics-server.yaml` and waits for rollout
- Applies app deployment (selected by `APP_MODE` + `PROFILE`) and waits for readiness
- Applies HPA manifest (selected by `PROFILE`)
- Prints cluster info and NodePort URL on success

| Task | Description |
|---|---|
| 4.1.1 | Create `scripts/lib/gate-bootstrap.sh` — implement `gate_bootstrap` |
| 4.1.2 | Implement idempotent KinD cluster creation (`kind get clusters | grep autoscaling-lab`) |
| 4.1.3 | Implement idempotent namespace creation |
| 4.1.4 | Implement metrics-server apply + `rollout status --timeout=180s` |
| 4.1.5 | Wire `apply_app_mode` (defined in E8) into `gate_bootstrap` |
| 4.1.6 | Implement deployment readiness wait with timeout |

---

### Story 4.2 — Reachability Gate

**As a** lab user,
**I want** a reachability gate that confirms the app is browser-accessible before load testing begins,
**so that** load starts against a provably live endpoint.

**Acceptance Criteria:**
- Detects NodePort for the service
- Smoke-checks `http://localhost:<nodeport>/` with curl (retry up to 3x with 5s backoff)
- Prints the lab URL to console: `Lab URL: http://localhost:<port>`
- Returns non-zero if HTTP response is not 2xx after retries

| Task | Description |
|---|---|
| 4.2.1 | Create `scripts/lib/gate-reachability.sh` — implement `gate_reachability` |
| 4.2.2 | Implement NodePort detection via `kubectl get svc -n <ns> -o jsonpath` |
| 4.2.3 | Implement curl smoke check with retry loop (3 attempts, 5s backoff) |
| 4.2.4 | Print `Lab URL: http://localhost:<port>` on pass |

---

## EPIC 5 — HPA Proof Gate

**Goal:** Implement `gate_hpa_proof` — the core autoscaling proof lifecycle from baseline to scale-up to cooldown, with timestamped replica samples and full HPA evidence artifacts.

---

### Story 5.1 — HPA Proof Lifecycle

**As a** lab runner,
**I want** a deterministic HPA proof gate that measures baseline, loads the service, observes scale-up, stops load, and observes cooldown,
**so that** autoscaling behavior is provably demonstrated with a timestamped artifact trail.

**Acceptance Criteria:**
- Precondition checks: HPA exists → 301; metrics available → 302; CPU requests set → 303
- Captures baseline replica count before load starts
- Starts load via `start_load <mode>` → 304 if fails
- Polls replicas every `HPA_POLL_SEC` for `HPA_RAMP_SEC`; tracks `max_seen`; exits loop on timeout
- If `max_seen <= baseline` after ramp: returns 305
- Stops load; polls for cooldown up to `HPA_COOLDOWN_SEC`; returns 306 if no decrease observed
- Writes all HPA artifacts to `${HPA_DIR}`

| Task | Description |
|---|---|
| 5.1.1 | Create `scripts/lib/gate-hpa-proof.sh` — implement `gate_hpa_proof` |
| 5.1.2 | Implement precondition checks (301, 302, 303) |
| 5.1.3 | Implement baseline capture and `replica_samples.csv` with `ts,replicas` rows |
| 5.1.4 | Implement scale-up polling loop with `max_seen` tracker |
| 5.1.5 | Implement cooldown polling loop |
| 5.1.6 | Implement `start_load` / `stop_load` delegators (route to `load.sh`) |

---

### Story 5.2 — HPA Evidence Artifacts

**As a** lab user,
**I want** HPA state captured to files before and after the proof loop,
**so that** I have a complete evidence bundle showing the cluster state during autoscaling.

**Acceptance Criteria:**
- `${HPA_DIR}/hpa_describe.txt` — output of `kubectl describe hpa`
- `${HPA_DIR}/hpa.yaml` — raw HPA resource YAML
- `${HPA_DIR}/top_nodes.txt` — `kubectl top nodes` output
- `${HPA_DIR}/top_pods.txt` — `kubectl top pods` output
- `${HPA_DIR}/replica_samples.csv` — timestamped replica counts (ts,replicas)
- `${HPA_DIR}/summary.txt` — PASS: baseline, max_seen, windows; or failure summary for 306

| Task | Description |
|---|---|
| 5.2.1 | Implement artifact collection calls in `gate_hpa_proof` (pre-load snapshots) |
| 5.2.2 | Implement `summary.txt` PASS variant writer |
| 5.2.3 | Implement `summary.txt` 306-variant writer (scale-up proved, cooldown not observed) |

---

## EPIC 6 — HPA Failure Codes & Fix Dispatcher

**Goal:** Implement the complete failure hint/routing layer and the deterministic `fix.sh` dispatcher with 3-attempt escalation for each of the 6 HPA failure codes.

---

### Story 6.1 — Failure Hint & Code Maps

**As a** lab user,
**I want** a clear, actionable failure message for each HPA error code,
**so that** I immediately know what went wrong and what the exact fix command is.

**Acceptance Criteria:**
- `print_failure_hint <code>` emits `[HPA-30X] <title>`, Check line, Fix line, Retry line for codes 301-306
- `print_next_command_for_code <code>` returns `./scripts/fix.sh HPA-30X`
- Unknown code → `[GENERIC-<code>]` without crashing

| Task | Description |
|---|---|
| 6.1.1 | Create `scripts/lib/failure-maps.sh` — implement `print_failure_hint` with cases 301-306 + `*` |
| 6.1.2 | Implement `print_next_command_for_code` in same file |
| 6.1.3 | Verify output format: `[HPA-30X] <title>\nCheck: ...\nFix: ...\nRetry: ...` |

---

### Story 6.2 — `fix.sh` Dispatcher & Attempt 1 (Canonical)

**As a** lab user,
**I want** `./scripts/fix.sh HPA-30X` to apply the canonical fix for that code, log the result, and tell me the next command,
**so that** recovery is a single deterministic action.

**Acceptance Criteria:**
- Accepts one positional arg (`HPA-301` through `HPA-306`); unknown → usage + exit 2
- Each fix function logs to `${FIX_DIR}/<code>.log` and writes `${FIX_DIR}/<code>.json`
- Every fix ends with `echo "Next command: ./scripts/up.sh --resume hpa_proof"`
- `log_fix_result` writes `{"code":"...","status":"...","note":"...","run_id":"..."}`

| Task | Description |
|---|---|
| 6.2.1 | Create `scripts/fix.sh` entrypoint with `CODE` arg parsing and `case` dispatch |
| 6.2.2 | Implement `log_fix_result` helper |
| 6.2.3 | Implement `fix_hpa_301` (Attempt 1): `kubectl apply -f k8s/hpa.yaml` + verify HPA exists |
| 6.2.4 | Implement `fix_hpa_302` (Attempt 1): apply `metrics-server.yaml` + rollout wait + verify `kubectl top nodes` |
| 6.2.5 | Implement `fix_hpa_303` (Attempt 1): `kubectl apply -f k8s/deployment.yaml` + rollout + verify CPU request |
| 6.2.6 | Implement `fix_hpa_304` (Attempt 1): `load.sh --mode ${LOAD_MODE}` + verify `--status` |
| 6.2.7 | Implement `fix_hpa_305` (Attempt 1): apply `k8s/presets/hpa-proof.yaml` + load preset start |
| 6.2.8 | Implement `fix_hpa_306` (Attempt 1): `load.sh --stop` + write `HPA_COOLDOWN_SEC=420` env override |

---

### Story 6.3 — 3-Attempt Escalation Ladder

**As a** lab user,
**I want** each fix to automatically try up to 3 escalating approaches before stopping,
**so that** transient or recoverable failures resolve without manual intervention.

**Acceptance Criteria:**
- Each fix code tracks attempt number (1, 2, 3)
- Attempt 2 (Tuned) per code:
  - 301: server-side re-apply + target ref adjustment
  - 302: restart metrics-server deployment with KinD-specific args
  - 303: patch CPU/memory requests directly via `kubectl patch`
  - 304: switch load mode (`pod→host` or `host→pod`)
  - 305: increase load intensity + extend ramp window
  - 306: patch `behavior.scaleDown` + extended cooldown observation
- Attempt 3 (Fallback) per code:
  - 301: delete + recreate HPA from known-good preset
  - 302: recreate metrics-server from pinned local KinD manifest
  - 303: apply tiny-safe fallback deployment preset
  - 304: start fallback minimal internal load profile
  - 305: lower HPA target to demo-safe value + switch to host-load fallback
  - 306: enforce zero-load + 420s observation window
- After 3 failed attempts: print bounded-stop message + escalation handoff bundle path

| Task | Description |
|---|---|
| 6.3.1 | Implement attempt tracking (`ATTEMPT` env or counter) in `fix.sh` |
| 6.3.2 | Implement Attempt 2 (Tuned) variants for HPA-301 through HPA-306 |
| 6.3.3 | Implement Attempt 3 (Fallback) variants for HPA-301 through HPA-306 |
| 6.3.4 | Implement bounded-stop message after 3 failed attempts |
| 6.3.5 | Create `k8s/presets/hpa-proof.yaml` (demo-safe HPA with low CPU target) |
| 6.3.6 | Create `k8s/presets/deployment-tiny-safe.yaml` (minimal requests deployment fallback) |
| 6.3.7 | Create `k8s/addons/metrics-server.yaml` pinned KinD-compatible manifest |

---

## EPIC 7 — Resume Path

**Goal:** Implement `up.sh --resume hpa_proof` so users can re-enter the pipeline after a fix without reprovisioning the cluster.

---

### Story 7.1 — Resume Sequence

**As a** lab user,
**I want** `./scripts/up.sh --resume hpa_proof` to run only the gates needed after a fix,
**so that** I skip reprovisioning and go straight back to proving autoscaling.

**Acceptance Criteria:**
- `--resume hpa_proof` triggers sequence: `bootstrap_integrity → reachability_gate → hpa_proof → evidence_capture`
- `bootstrap_integrity` is read-only: checks `kind get clusters`, namespace exists, deployment healthy — no recreate
- Uses prior `RUN_ID` from `.state/last_run_id` unless `--run-id` is specified
- `--profile`, `--app-mode`, `--load-mode` args are respected in resumed gates
- Resume mode propagated to outcome resolver (`mode=resume`)

| Task | Description |
|---|---|
| 7.1.1 | Implement `gate_bootstrap_integrity` in `scripts/lib/gate-bootstrap.sh` (read-only kubectl checks) |
| 7.1.2 | Implement `resume_hpa_proof_run` sequence in `up.sh` |
| 7.1.3 | Add `--resume`, `--run-id`, `--profile`, `--app-mode`, `--load-mode` to `up.sh` `parse_args` |
| 7.1.4 | Implement `resolve_run_id` resume branch: reads `.state/last_run_id` when `--resume` set |
| 7.1.5 | Propagate `RESUME_TARGET` to `print_next_action_from_scorecard` for mode differentiation |

---

## EPIC 8 — D3 Delivery Model: App & Load Modes

**Goal:** Implement switchable `APP_MODE` (landing/api), switchable `LOAD_MODE` (pod/host), and profile-aware Kubernetes manifests.

---

### Story 8.1 — Dual App Mode

**As a** lab user,
**I want** to switch between a landing-page and API app via `APP_MODE=landing|api`,
**so that** I can demonstrate autoscaling with the workload shape most relevant to me.

**Acceptance Criteria:**
- `APP_MODE=landing`: deploys `k8s/app/landing/deployment.yaml` (HTML landing page)
- `APP_MODE=api`: deploys `k8s/app/api/deployment.yaml` (single JSON endpoint)
- Both expose on same NodePort range; both have CPU resource requests set
- `apply_app_mode` selects correct deployment + HPA based on `APP_MODE` + `PROFILE`

| Task | Description |
|---|---|
| 8.1.1 | Create `k8s/app/landing/deployment.yaml` + `k8s/app/landing/service.yaml` |
| 8.1.2 | Create `k8s/app/api/deployment.yaml` + `k8s/app/api/service.yaml` |
| 8.1.3 | Create profile HPA manifests: `k8s/hpa-tiny.yaml`, `k8s/hpa-balanced.yaml`, `k8s/hpa-stretch.yaml` |
| 8.1.4 | Implement `apply_app_mode` function routing `APP_MODE + PROFILE` to correct manifests |

---

### Story 8.2 — Dual Load Mode

**As a** lab user,
**I want** `LOAD_MODE=pod|host` to switch between in-cluster and host-side load generation,
**so that** I can prove autoscaling via both isolated and real-world network paths.

**Acceptance Criteria:**
- `load.sh --mode pod`: starts a load-generator pod in namespace; labeled for cleanup
- `load.sh --mode host`: starts a host-side curl loop; PID tracked in `.state/load.pid`
- `load.sh --status`: prints `active` or `stopped`
- `load.sh --stop`: cleans up pod or kills PID
- `load.sh --preset hpa-proof`: applies cap-aware low-intensity settings

| Task | Description |
|---|---|
| 8.2.1 | Create `scripts/load.sh` with `--mode`, `--status`, `--stop`, `--preset` arg parsing |
| 8.2.2 | Implement `start_load_pod`: deploy `busybox` curl-loop pod, labeled `app=load-generator` |
| 8.2.3 | Implement `start_load_host`: background curl loop; write PID to `.state/load.pid` |
| 8.2.4 | Implement `stop_load_pod`: delete pods by label |
| 8.2.5 | Implement `stop_load_host`: read + kill PID from `.state/load.pid` |
| 8.2.6 | Implement `status_load`: check pod running or PID alive |
| 8.2.7 | Implement `--preset hpa-proof`: set low RPS/concurrency matching `tiny` profile |

---

### Story 8.3 — Profile Ladder & Admission Guard

**As a** lab user,
**I want** `PROFILE=tiny|balanced|stretch` to control `maxReplicas` and be guarded by memory checks,
**so that** I choose a profile that fits my machine without the lab hanging or thrashing.

**Acceptance Criteria:**
- `tiny`: maxReplicas=5, works on ≥ 2GB available RAM
- `balanced`: maxReplicas=7, requires ≥ 4GB; warn if below
- `stretch`: maxReplicas=10, requires ≥ 8GB; block if below
- Warning message includes next-profile-down suggestion
- Guard runs at start of `up.sh` before any provisioning

| Task | Description |
|---|---|
| 8.3.1 | Implement `profile_admission_guard` in `scripts/lib/config.sh` |
| 8.3.2 | Implement cross-OS available memory detection (Linux: `free -m`; macOS: `vm_stat` parse) |
| 8.3.3 | Implement warn/block branching with downgrade suggestion message |

---

## EPIC 9 — Evidence Capture & Teardown

**Goal:** Implement the evidence capture gate, standalone evidence collection script, and clean teardown with integrity verification.

---

### Story 9.1 — Evidence Capture Gate

**As a** lab user,
**I want** a non-critical evidence gate that collects kubectl state snapshots and generates a checklist,
**so that** I have a complete, reviewer-ready evidence bundle after every successful proof.

**Acceptance Criteria:**
- `gate_evidence_capture` collects: `kubectl get all -n <ns>`, `kubectl describe hpa`, replica samples CSV check
- Generates `${ARTIFACT_ROOT}/evidence-checklist.md` with pass/fail checkboxes
- NON_CRITICAL: failure does not block success; emits warn + suggests `collect-evidence.sh`
- `scripts/collect-evidence.sh` re-runs evidence capture standalone (accepts `--run-id`, `--from-resume`)

| Task | Description |
|---|---|
| 9.1.1 | Create `scripts/lib/gate-evidence.sh` — implement `gate_evidence_capture` |
| 9.1.2 | Implement `evidence-checklist.md` generator with checkboxes: output captured, CSV present, screenshot placeholder |
| 9.1.3 | Create `scripts/collect-evidence.sh` — standalone re-run with `--run-id` and `--from-resume` args |

---

### Story 9.2 — Teardown & Integrity Gate

**As a** lab user,
**I want** `./scripts/down.sh` to cleanly remove all lab resources and verify re-run is possible,
**so that** every lifecycle ends reproducibly.

**Acceptance Criteria:**
- `down.sh` deletes namespace (`kubectl delete ns autoscaling-lab`)
- `down.sh` optionally deletes KinD cluster (`--delete-cluster` flag or default behavior TBD)
- `--preserve-artifacts` skips artifact directory deletion
- `gate_teardown_integrity` (NON_CRITICAL): verifies cluster still listed or namespace deleted
- After teardown, `up.sh` can be re-run cleanly

| Task | Description |
|---|---|
| 9.2.1 | Create `scripts/down.sh` with `--run-id`, `--preserve-artifacts`, `--delete-cluster` arg parsing |
| 9.2.2 | Implement namespace deletion with confirmation output |
| 9.2.3 | Implement optional KinD cluster deletion |
| 9.2.4 | Implement `gate_teardown_integrity` in `scripts/lib/gate-teardown.sh` |

---

## EPIC 10 — Documentation & Learner Experience

**Goal:** Produce the canonical documentation set: quick-start, configuration reference, troubleshooting cards, and conceptual framing.

---

### Story 10.1 — Quick-Start & Concepts Docs

**As a** beginner learner (Audience A),
**I want** a quick-start guide that gets me to a successful HPA proof in under 15 minutes,
**so that** I build confidence before going deeper.

**Acceptance Criteria:**
- `docs/quick-start.md`: prerequisites checklist → `up.sh` → observe scorecard → `down.sh` — minimal prose, commands-first
- `docs/concepts.md`: Docker-to-K8s bridge framing, two-layer mental model (app → orchestration → behavior)
- Both docs tested against a fresh-install path by a human reviewer

| Task | Description |
|---|---|
| 10.1.1 | Write `docs/quick-start.md`: prerequisites, single command flow, how to read scorecard |
| 10.1.2 | Write `docs/concepts.md`: Docker-to-K8s bridge, HPA mental model, NodePort explanation |
| 10.1.3 | Add cross-OS notes (Linux vs macOS differences) to quick-start |

---

### Story 10.2 — Configuration & Troubleshooting Docs

**As an** intermediate user (Audience B),
**I want** a full configuration reference and troubleshooting cards for each HPA failure code,
**so that** I can tune profiles and recover independently.

**Acceptance Criteria:**
- `docs/configuration.md`: all env vars, profiles, modes, defaults, memory requirements
- `docs/troubleshooting.md`: one card per HPA-301..306 with Symptom / Check / Fix / Retry fields (mirrors `print_failure_hint`)
- Both docs kept in sync with script behavior (single source of truth is script; docs mirror it)

| Task | Description |
|---|---|
| 10.2.1 | Write `docs/configuration.md`: all env vars with defaults, allowed values, profile table |
| 10.2.2 | Write `docs/troubleshooting.md`: 6 failure code cards matching `print_failure_hint` output format |
| 10.2.3 | Add profile-specific expectations section: what to expect per profile during proof |
| 10.2.4 | Add `docs/artifact-reference.md`: annotated artifact tree with field descriptions |

---

*Epics derived from `product-brief.md` v1.0 | BMad Master v6.0.4 | 2026-03-06*
