# Story E1-S2 — Configuration Surface (`config.sh`)

**Epic:** E1 — Project Scaffold & Configuration Surface
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** a single configuration file that defines all environment variables with documented defaults,
**so that** I can control `APP_MODE`, `LOAD_MODE`, and `PROFILE` without editing scripts.

---

## Acceptance Criteria

- `scripts/lib/config.sh` exports: `APP_MODE` (default: `landing`), `LOAD_MODE` (default: `pod`), `PROFILE` (default: `tiny`), `NAMESPACE` (default: `autoscaling-lab`), `APP_DEPLOYMENT`, `HPA_NAME`, timing vars (`HPA_RAMP_SEC`, `HPA_COOLDOWN_SEC`, `HPA_POLL_SEC`)
- Profile → maxReplicas lookup returns: `tiny=5`, `balanced=7`, `stretch=10`
- Profile admission guard: warn if `balanced` and < 4GB available; block if `stretch` and < 8GB available
- All variables respect pre-set environment (`${VAR:-default}` pattern)

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 1.2.1 | Create `scripts/lib/config.sh` with all env var defaults | Pending |
| 1.2.2 | Implement `get_max_replicas` function: `case $PROFILE in tiny) echo 5;; balanced) echo 7;; stretch) echo 10;; esac` | Pending |
| 1.2.3 | Implement `profile_admission_guard`: check `free -m` (Linux) / `vm_stat` (macOS) against profile thresholds | Pending |
| 1.2.4 | Implement cross-OS memory check helper with graceful degradation if command unavailable | Pending |
| 1.2.5 | Document all env vars in `docs/configuration.md` with default values and allowed values | Pending |
