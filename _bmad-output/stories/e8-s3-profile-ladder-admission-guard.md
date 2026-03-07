# Story E8-S3 — Profile Ladder & Admission Guard

**Epic:** E8 — D3 Delivery Model: App & Load Modes
**Status:** Done

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

### Task 8.3.1 — Implement `profile_admission_guard` in `scripts/lib/config.sh`
- [x] Add `profile_admission_guard()` function to `scripts/lib/config.sh`
- [x] Read `PROFILE` from environment (default: `tiny` if unset)
- [x] Call `get_available_ram_mb()` to get available RAM in MB
- [x] For `tiny`: require `AVAIL_RAM_MB >= 2048`; if below, print warning but do NOT block (tiny is always runnable)
- [x] For `balanced`: require `AVAIL_RAM_MB >= 4096`; if below, print warning with suggestion `Consider using PROFILE=tiny`; return 0 (warn-only)
- [x] For `stretch`: require `AVAIL_RAM_MB >= 8192`; if below, print error with suggestion `Use PROFILE=balanced or PROFILE=tiny`; return 1 (block)
- [x] Invalid `PROFILE` value: print `Unknown profile: ${PROFILE}. Valid values: tiny, balanced, stretch`; return 1

### Task 8.3.2 — Implement cross-OS available memory detection (Linux: `free -m`; macOS: `vm_stat` parse)
- [x] Define `get_available_ram_mb()` function
- [x] Detect OS: `uname -s` → `Linux` or `Darwin`
- [x] Linux path: `free -m | awk '/^Mem:/ {print $7}'` (available column) — assign to `AVAIL_RAM_MB`
- [x] macOS path: parse `vm_stat` output:
  - [x] Get `Pages free` and `Pages inactive` values from `vm_stat`
  - [x] Multiply sum by 4096 (page size) and divide by 1048576 to convert to MB
  - [x] Store result in `AVAIL_RAM_MB`
- [x] If OS is neither Linux nor Darwin: set `AVAIL_RAM_MB=99999` (skip guard) and print `Warning: OS not recognized, skipping memory guard`
- [x] Echo `${AVAIL_RAM_MB}` as return value (callers use `AVAIL_RAM_MB=$(get_available_ram_mb)`)

### Task 8.3.3 — Implement warn/block branching with downgrade suggestion message
- [x] Warning message format: `[WARN] Profile '${PROFILE}' recommends ${REQUIRED_MB}MB RAM but only ~${AVAIL_RAM_MB}MB available.`
- [x] Follow warning with: `Suggestion: set PROFILE=${NEXT_PROFILE_DOWN} to avoid instability.`
- [x] Block message format: `[ERROR] Profile 'stretch' requires ≥8GB RAM. Only ~${AVAIL_RAM_MB}MB available. Aborting.`
- [x] Suggestion table: stretch → balanced; balanced → tiny (hardcoded in function)
- [x] Call `profile_admission_guard` at the top of the main flow in `up.sh`, before `gate_bootstrap` or any provisioning
- [x] If guard returns non-zero, `up.sh` exits immediately with exit code 1
