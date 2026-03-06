# Story E6-S3 — 3-Attempt Escalation Ladder

**Epic:** E6 — HPA Failure Codes & Fix Dispatcher
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** each fix to automatically try up to 3 escalating approaches before stopping,
**so that** transient or recoverable failures resolve without manual intervention.

---

## Acceptance Criteria

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

---

## Tasks

### Task 6.3.1 — Implement attempt tracking (`ATTEMPT` env or counter) in `fix.sh`
- [ ] Read `ATTEMPT` from environment: `ATTEMPT="${ATTEMPT:-1}"`
- [ ] Validate `ATTEMPT` is 1, 2, or 3; if outside range, print error and `exit 2`
- [ ] Pass `ATTEMPT` through to each `fix_hpa_<code>` function via exported env or function arg
- [ ] After each fix function call: if it returned non-zero, increment `ATTEMPT` and re-dispatch (loop until `ATTEMPT > 3`)
- [ ] After 3 failed attempts: call `print_bounded_stop "${CODE}"` and `exit 1`
- [ ] Write `ATTEMPT=${ATTEMPT}` into the per-code JSON artifact from `log_fix_result`

### Task 6.3.2 — Implement Attempt 2 (Tuned) variants for HPA-301 through HPA-306
- [ ] **301 Tuned**: `kubectl apply --server-side -f k8s/hpa.yaml -n ${NAMESPACE}`; then patch `spec.scaleTargetRef.name` to match current deployment name
- [ ] **302 Tuned**: `kubectl -n kube-system rollout restart deploy/metrics-server`; wait for rollout; add `--kubelet-insecure-tls` arg via patch if missing
- [ ] **303 Tuned**: `kubectl -n ${NAMESPACE} patch deploy/${APP_DEPLOYMENT} -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'`; wait rollout
- [ ] **304 Tuned**: if `LOAD_MODE=pod` switch to `host`; else switch to `pod`; write new mode to `.state/env-overrides`; start load with switched mode
- [ ] **305 Tuned**: increase ramp: write `HPA_RAMP_SEC=300` to `.state/env-overrides`; start load with higher concurrency (`./scripts/load.sh --preset hpa-proof --concurrency 50`)
- [ ] **306 Tuned**: patch HPA behavior: `kubectl -n ${NAMESPACE} patch hpa ${HPA_NAME} --type merge -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":60}}}}'`; write `HPA_COOLDOWN_SEC=300` override

### Task 6.3.3 — Implement Attempt 3 (Fallback) variants for HPA-301 through HPA-306
- [ ] **301 Fallback**: `kubectl -n ${NAMESPACE} delete hpa ${HPA_NAME} --ignore-not-found`; then `kubectl apply -f k8s/presets/hpa-proof.yaml -n ${NAMESPACE}`; verify HPA exists
- [ ] **302 Fallback**: `kubectl -n kube-system delete deploy/metrics-server --ignore-not-found`; `kubectl apply -f k8s/addons/metrics-server.yaml` (pinned KinD manifest); rollout wait 180s
- [ ] **303 Fallback**: `kubectl apply -f k8s/presets/deployment-tiny-safe.yaml -n ${NAMESPACE}`; rollout wait; verify CPU request
- [ ] **304 Fallback**: start minimal internal load: `kubectl run load-fallback --image=busybox -n ${NAMESPACE} -- /bin/sh -c "while true; do wget -q -O- http://${APP_DEPLOYMENT}/; done"` with low rate
- [ ] **305 Fallback**: patch HPA `spec.metrics[0].resource.target.averageUtilization` to `20`; switch to `host` load mode; write both overrides to `.state/env-overrides`
- [ ] **306 Fallback**: `./scripts/load.sh --stop`; write `HPA_COOLDOWN_SEC=420` to `.state/env-overrides`; log that a full 7-minute observation window will be used

### Task 6.3.4 — Implement bounded-stop message after 3 failed attempts
- [ ] Define `print_bounded_stop()` function accepting `code` arg
- [ ] Print header: `=== Recovery Bounded: ${code} failed after 3 attempts ===`
- [ ] Print escalation bundle path: `Handoff bundle: ${ARTIFACT_ROOT}/fix-escalation-${code}.tar.gz`
- [ ] Create the tar bundle: `tar czf ${ARTIFACT_ROOT}/fix-escalation-${code}.tar.gz ${FIX_DIR}/${code}*.log ${FIX_DIR}/${code}*.json`
- [ ] Print manual recovery note: `Manual intervention required. See docs/troubleshooting.md#${code}`
- [ ] Call `log_fix_result "${code}" "bounded_stop" "3 attempts exhausted"` to write final JSON state

### Task 6.3.5 — Create `k8s/presets/hpa-proof.yaml` (demo-safe HPA with low CPU target)
- [ ] Create `k8s/presets/hpa-proof.yaml` as a valid HPA manifest
- [ ] Set `spec.minReplicas: 1`, `spec.maxReplicas: 5` (tiny-safe)
- [ ] Set CPU utilization target: `averageUtilization: 20` (low threshold to ensure scaling triggers under demo load)
- [ ] Set `scaleTargetRef` to `${APP_DEPLOYMENT}` placeholder; document substitution requirement in a comment
- [ ] Include `metadata.labels: preset: hpa-proof` for identification

### Task 6.3.6 — Create `k8s/presets/deployment-tiny-safe.yaml` (minimal requests deployment fallback)
- [ ] Create `k8s/presets/deployment-tiny-safe.yaml` as a valid Deployment manifest
- [ ] Set `resources.requests.cpu: "50m"` and `resources.requests.memory: "64Mi"` (intentionally minimal)
- [ ] Set `resources.limits.cpu: "200m"` and `resources.limits.memory: "128Mi"`
- [ ] Use same container image reference as `k8s/app/landing/deployment.yaml` (landing page is default fallback)
- [ ] Include `metadata.labels: preset: deployment-tiny-safe`

### Task 6.3.7 — Create `k8s/addons/metrics-server.yaml` pinned KinD-compatible manifest
- [ ] Create `k8s/addons/metrics-server.yaml` using a pinned metrics-server version (e.g., v0.6.3 or latest stable)
- [ ] Add `--kubelet-insecure-tls` to the metrics-server container args (required for KinD)
- [ ] Add `--kubelet-preferred-address-types=InternalIP` to the container args (KinD compatibility)
- [ ] Verify the manifest applies cleanly to a fresh KinD cluster with `kubectl apply -f k8s/addons/metrics-server.yaml`
- [ ] Document the pinned version in a comment at the top of the file
