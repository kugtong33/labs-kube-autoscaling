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
- Creates namespace `autoscaling-lab` (idempotent: `--dry-run=client -o yaml | kubectl apply -f -` or `kubectl create ns ... --ignore-not-found`)
- Applies `k8s/addons/metrics-server.yaml` and waits for rollout
- Applies app deployment (selected by `APP_MODE` + `PROFILE`) and waits for readiness
- Applies HPA manifest (selected by `PROFILE`)
- Prints cluster info and NodePort URL on success

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 4.1.1 | Create `scripts/lib/gate-bootstrap.sh` — implement `gate_bootstrap` | Pending |
| 4.1.2 | Implement idempotent KinD cluster creation (`kind get clusters | grep autoscaling-lab`) | Pending |
| 4.1.3 | Implement idempotent namespace creation | Pending |
| 4.1.4 | Implement metrics-server apply + `rollout status --timeout=180s` | Pending |
| 4.1.5 | Wire `apply_app_mode` (defined in E8) into `gate_bootstrap` | Pending |
| 4.1.6 | Implement deployment readiness wait with timeout | Pending |
