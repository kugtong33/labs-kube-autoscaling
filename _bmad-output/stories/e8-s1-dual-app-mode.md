# Story E8-S1 — Dual App Mode

**Epic:** E8 — D3 Delivery Model: App & Load Modes
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** to switch between a landing-page and API app via `APP_MODE=landing|api`,
**so that** I can demonstrate autoscaling with the workload shape most relevant to me.

---

## Acceptance Criteria

- `APP_MODE=landing`: deploys `k8s/app/landing/deployment.yaml` (HTML landing page)
- `APP_MODE=api`: deploys `k8s/app/api/deployment.yaml` (single JSON endpoint)
- Both expose on same NodePort range; both have CPU resource requests set
- `apply_app_mode` selects correct deployment + HPA based on `APP_MODE` + `PROFILE`

---

## Tasks

### Task 8.1.1 — Create `k8s/app/landing/deployment.yaml` + `k8s/app/landing/service.yaml`
- [ ] Create `k8s/app/landing/deployment.yaml` as a valid Kubernetes Deployment
- [ ] Use a lightweight HTTP server image (e.g., `nginx:alpine`) serving a simple HTML landing page
- [ ] Set `resources.requests.cpu: "100m"` and `resources.requests.memory: "128Mi"` on the container
- [ ] Set `resources.limits.cpu: "500m"` and `resources.limits.memory: "256Mi"`
- [ ] Set `metadata.labels: app: autoscaling-lab, mode: landing`
- [ ] Create `k8s/app/landing/service.yaml` as a NodePort Service
- [ ] Expose port 80 via NodePort in the 30000-32767 range (use a fixed port, e.g., 30080)
- [ ] Set `selector: app: autoscaling-lab` to match the deployment

### Task 8.1.2 — Create `k8s/app/api/deployment.yaml` + `k8s/app/api/service.yaml`
- [ ] Create `k8s/app/api/deployment.yaml` as a valid Kubernetes Deployment
- [ ] Use a lightweight HTTP server serving a single JSON endpoint at `/` (e.g., `{"status":"ok"}`)
- [ ] Set `resources.requests.cpu: "100m"` and `resources.requests.memory: "128Mi"` (same as landing)
- [ ] Set `metadata.labels: app: autoscaling-lab, mode: api`
- [ ] Create `k8s/app/api/service.yaml` as a NodePort Service
- [ ] Use the same NodePort (30080) as landing so that `gate_reachability` logic is identical regardless of mode

### Task 8.1.3 — Create profile HPA manifests: `k8s/hpa-tiny.yaml`, `k8s/hpa-balanced.yaml`, `k8s/hpa-stretch.yaml`
- [ ] Create `k8s/hpa-tiny.yaml`: `minReplicas: 1`, `maxReplicas: 5`, `averageUtilization: 50`
- [ ] Create `k8s/hpa-balanced.yaml`: `minReplicas: 1`, `maxReplicas: 7`, `averageUtilization: 50`
- [ ] Create `k8s/hpa-stretch.yaml`: `minReplicas: 1`, `maxReplicas: 10`, `averageUtilization: 50`
- [ ] All three HPAs target `scaleTargetRef.name: ${APP_DEPLOYMENT}` — document that this must match actual deployment name
- [ ] All three HPAs are in namespace `autoscaling-lab`
- [ ] Verify YAML is valid: `kubectl --dry-run=client apply -f k8s/hpa-tiny.yaml` (and balanced, stretch)

### Task 8.1.4 — Implement `apply_app_mode` function routing `APP_MODE + PROFILE` to correct manifests
- [ ] Create `scripts/lib/app-mode.sh` with shebang and sourcing guard
- [ ] Define `apply_app_mode()` function accepting no args; reads `APP_MODE` and `PROFILE` from environment
- [ ] Validate `APP_MODE` is `landing` or `api`; print error and return 1 if invalid
- [ ] Validate `PROFILE` is `tiny`, `balanced`, or `stretch`; print error and return 1 if invalid
- [ ] Apply deployment: `kubectl apply -f k8s/app/${APP_MODE}/deployment.yaml -n ${NAMESPACE}`
- [ ] Apply service: `kubectl apply -f k8s/app/${APP_MODE}/service.yaml -n ${NAMESPACE}`
- [ ] Apply HPA: `kubectl apply -f k8s/hpa-${PROFILE}.yaml -n ${NAMESPACE}`
- [ ] Wait for deployment rollout: `kubectl -n ${NAMESPACE} rollout status deploy/${APP_DEPLOYMENT} --timeout=180s`
- [ ] Print confirmation: `App mode: ${APP_MODE}, Profile: ${PROFILE} — applied`
