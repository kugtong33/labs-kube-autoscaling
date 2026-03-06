# Story E8-S3 — Profile Ladder & Admission Guard

**Epic:** E8 — D3 Delivery Model: App & Load Modes
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** `PROFILE=tiny|balanced|stretch` to control `maxReplicas` and be guarded by memory checks,
**so that** I choose a profile that fits my machine without the lab hanging or thrashing.

---

## Acceptance Criteria

- `tiny`: maxReplicas=5, works on ≥ 2GB available RAM
- `balanced`: maxReplicas=7, requires ≥ 4GB; warn if below
- `stretch`: maxReplicas=10, requires ≥ 8GB; block if below
- Warning message includes next-profile-down suggestion
- Guard runs at start of `up.sh` before any provisioning

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 8.3.1 | Implement `profile_admission_guard` in `scripts/lib/config.sh` | Pending |
| 8.3.2 | Implement cross-OS available memory detection (Linux: `free -m`; macOS: `vm_stat` parse) | Pending |
| 8.3.3 | Implement warn/block branching with downgrade suggestion message | Pending |
