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

| ID | Task | Status |
|---|---|---|
| 6.3.1 | Implement attempt tracking (`ATTEMPT` env or counter) in `fix.sh` | Pending |
| 6.3.2 | Implement Attempt 2 (Tuned) variants for HPA-301 through HPA-306 | Pending |
| 6.3.3 | Implement Attempt 3 (Fallback) variants for HPA-301 through HPA-306 | Pending |
| 6.3.4 | Implement bounded-stop message after 3 failed attempts | Pending |
| 6.3.5 | Create `k8s/presets/hpa-proof.yaml` (demo-safe HPA with low CPU target) | Pending |
| 6.3.6 | Create `k8s/presets/deployment-tiny-safe.yaml` (minimal requests deployment fallback) | Pending |
| 6.3.7 | Create `k8s/addons/metrics-server.yaml` pinned KinD-compatible manifest | Pending |
