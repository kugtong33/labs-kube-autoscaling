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

| ID | Task | Status |
|---|---|---|
| 8.1.1 | Create `k8s/app/landing/deployment.yaml` + `k8s/app/landing/service.yaml` | Pending |
| 8.1.2 | Create `k8s/app/api/deployment.yaml` + `k8s/app/api/service.yaml` | Pending |
| 8.1.3 | Create profile HPA manifests: `k8s/hpa-tiny.yaml`, `k8s/hpa-balanced.yaml`, `k8s/hpa-stretch.yaml` | Pending |
| 8.1.4 | Implement `apply_app_mode` function routing `APP_MODE + PROFILE` to correct manifests | Pending |
