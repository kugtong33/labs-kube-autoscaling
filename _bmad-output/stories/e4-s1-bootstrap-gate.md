# Story E4-S1 — Bootstrap Gate

**Epic:** E4 — Bootstrap & Reachability Gates
**Status:** Pending

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
- [ ] Create file with shebang and sourcing guard
- [ ] Define `gate_bootstrap()` function skeleton
- [ ] Source required lib files (`config.sh`)

### Task 4.1.2 — Implement idempotent KinD cluster creation
- [ ] Run `kind get clusters` and check for `autoscaling-lab`
- [ ] Skip creation if cluster already exists; print skip message
- [ ] Run `kind create cluster --name autoscaling-lab` if not exists
- [ ] Verify cluster reachable: `kubectl cluster-info --context kind-autoscaling-lab`

### Task 4.1.3 — Implement idempotent namespace creation
- [ ] Run `kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -`
- [ ] Verify namespace exists: `kubectl get ns ${NAMESPACE}`

### Task 4.1.4 — Implement metrics-server apply and rollout wait
- [ ] Apply `k8s/addons/metrics-server.yaml`
- [ ] Wait: `kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s`
- [ ] Verify `kubectl top nodes` succeeds after rollout

### Task 4.1.5 — Wire `apply_app_mode` (defined in E8) into `gate_bootstrap`
- [ ] Source `scripts/lib/app-mode.sh` (defined in E8-S1)
- [ ] Call `apply_app_mode` with current `APP_MODE` and `PROFILE`

### Task 4.1.6 — Implement deployment readiness wait with timeout
- [ ] Wait: `kubectl -n ${NAMESPACE} rollout status deploy/${APP_DEPLOYMENT} --timeout=180s`
- [ ] Print `NodePort URL: http://localhost:<port>` on success
