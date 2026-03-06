# Story E4-S1 — Bootstrap Gate

**Epic:** E4 — Bootstrap & Reachability Gates
**Status:** Done

---

## User Story

**As a** lab runner,
**I want** a bootstrap gate that provisions the full cluster stack idempotently,
**so that** the lab reaches a known-good state before any autoscaling test begins.

---

## Acceptance Criteria

- Creates KinD cluster only if it does not already exist (`kind get clusters` check)
- Creates namespace `autoscaling-lab` (idempotent)
- Applies `k8s/addons/metrics-server.yaml` and waits for rollout
- Applies app deployment (selected by `APP_MODE` + `PROFILE`) and waits for readiness
- Applies HPA manifest (selected by `PROFILE`)
- Prints cluster info and NodePort URL on success

---

## Tasks

### Task 4.1.1 — Create `scripts/lib/gate-bootstrap.sh` — implement `gate_bootstrap`
- [x] Create file with shebang and sourcing guard
- [x] Define `gate_bootstrap()` function skeleton
- [x] Source required lib files (`config.sh`)

### Task 4.1.2 — Implement idempotent KinD cluster creation
- [x] Run `kind get clusters` and check for `autoscaling-lab`
- [x] Skip creation if cluster already exists; print skip message
- [x] Run `kind create cluster --name autoscaling-lab` if not exists
- [x] Verify cluster reachable: `kubectl cluster-info --context kind-autoscaling-lab`

### Task 4.1.3 — Implement idempotent namespace creation
- [x] Run `kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -`
- [x] Verify namespace exists: `kubectl get ns ${NAMESPACE}`

### Task 4.1.4 — Implement metrics-server apply and rollout wait
- [x] Apply `k8s/addons/metrics-server.yaml`
- [x] Wait: `kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s`
- [x] Verify `kubectl top nodes` succeeds after rollout

### Task 4.1.5 — Wire `apply_app_mode` (defined in E8) into `gate_bootstrap`
- [x] Source `scripts/lib/app-mode.sh` (defined in E8-S1)
- [x] Call `apply_app_mode` with current `APP_MODE` and `PROFILE`

### Task 4.1.6 — Implement deployment readiness wait with timeout
- [x] Wait: `kubectl -n ${NAMESPACE} rollout status deploy/${APP_DEPLOYMENT} --timeout=180s`
- [x] Print `NodePort URL: http://localhost:<port>` on success
