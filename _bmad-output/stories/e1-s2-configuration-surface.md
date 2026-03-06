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

### Task 1.2.1 — Create `scripts/lib/config.sh` with all env var defaults
- [ ] Create file with shebang and sourcing guard (`[[ -n $__CONFIG_SH ]] && return; __CONFIG_SH=1`)
- [ ] Export `APP_MODE` with default `landing`
- [ ] Export `LOAD_MODE` with default `pod`
- [ ] Export `PROFILE` with default `tiny`
- [ ] Export `NAMESPACE` with default `autoscaling-lab`
- [ ] Export `APP_DEPLOYMENT` with default `sample-app`
- [ ] Export `HPA_NAME` with default `sample-app-hpa`
- [ ] Export `HPA_RAMP_SEC` with default `180`
- [ ] Export `HPA_COOLDOWN_SEC` with default `240`
- [ ] Export `HPA_POLL_SEC` with default `10`

### Task 1.2.2 — Implement `get_max_replicas` function
- [ ] Define `get_max_replicas()` function
- [ ] Handle `tiny` → echo `5`
- [ ] Handle `balanced` → echo `7`
- [ ] Handle `stretch` → echo `10`
- [ ] Handle unknown profile → print error and return 1

### Task 1.2.3 — Implement `profile_admission_guard`
- [ ] Define `profile_admission_guard()` function
- [ ] Call `get_available_memory_mb` to get available RAM
- [ ] If `PROFILE=balanced` and RAM < 4096: print warn + downgrade suggestion
- [ ] If `PROFILE=stretch` and RAM < 8192: print block message and exit 1
- [ ] Skip guard gracefully if memory detection is unavailable

### Task 1.2.4 — Implement cross-OS memory check helper
- [ ] Define `get_available_memory_mb()` function
- [ ] Detect OS via `uname -s`
- [ ] Linux path: parse `free -m | awk '/^Mem:/{print $7}'`
- [ ] macOS path: parse `vm_stat` pages free × 4 (pages are 4KB)
- [ ] Return `0` if neither command is available (graceful degradation)

### Task 1.2.5 — Document all env vars in `docs/configuration.md`
- [ ] Create `docs/configuration.md`
- [ ] Document `APP_MODE`: values (`landing`|`api`), default, effect
- [ ] Document `LOAD_MODE`: values (`pod`|`host`), default, effect
- [ ] Document `PROFILE`: values, default, maxReplicas mapping, min RAM per profile
- [ ] Document `NAMESPACE`, `APP_DEPLOYMENT`, `HPA_NAME` with defaults
- [ ] Document timing vars: `HPA_RAMP_SEC`, `HPA_COOLDOWN_SEC`, `HPA_POLL_SEC`
- [ ] Add usage examples showing env var override syntax
