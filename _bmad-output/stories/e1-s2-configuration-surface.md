# Story E1-S2 — Configuration Surface (`config.sh`)

**Epic:** E1 — Project Scaffold & Configuration Surface
**Status:** Done

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
- [x] Create file with shebang and sourcing guard (`[[ -n $__CONFIG_SH ]] && return; __CONFIG_SH=1`)
- [x] Export `APP_MODE` with default `landing`
- [x] Export `LOAD_MODE` with default `pod`
- [x] Export `PROFILE` with default `tiny`
- [x] Export `NAMESPACE` with default `autoscaling-lab`
- [x] Export `APP_DEPLOYMENT` with default `sample-app`
- [x] Export `HPA_NAME` with default `sample-app-hpa`
- [x] Export `HPA_RAMP_SEC` with default `180`
- [x] Export `HPA_COOLDOWN_SEC` with default `240`
- [x] Export `HPA_POLL_SEC` with default `10`

### Task 1.2.2 — Implement `get_max_replicas` function
- [x] Define `get_max_replicas()` function
- [x] Handle `tiny` → echo `5`
- [x] Handle `balanced` → echo `7`
- [x] Handle `stretch` → echo `10`
- [x] Handle unknown profile → print error and return 1

### Task 1.2.3 — Implement `profile_admission_guard`
- [x] Define `profile_admission_guard()` function
- [x] Call `get_available_memory_mb` to get available RAM
- [x] If `PROFILE=balanced` and RAM < 4096: print warn + downgrade suggestion
- [x] If `PROFILE=stretch` and RAM < 8192: print block message and exit 1
- [x] Skip guard gracefully if memory detection is unavailable

### Task 1.2.4 — Implement cross-OS memory check helper
- [x] Define `get_available_memory_mb()` function
- [x] Detect OS via `uname -s`
- [x] Linux path: parse `free -m | awk '/^Mem:/{print $7}'`
- [x] macOS path: parse `vm_stat` pages free × 4 (pages are 4KB)
- [x] Return `0` if neither command is available (graceful degradation)

### Task 1.2.5 — Document all env vars in `docs/configuration.md`
- [x] Create `docs/configuration.md`
- [x] Document `APP_MODE`: values (`landing`|`api`), default, effect
- [x] Document `LOAD_MODE`: values (`pod`|`host`), default, effect
- [x] Document `PROFILE`: values, default, maxReplicas mapping, min RAM per profile
- [x] Document `NAMESPACE`, `APP_DEPLOYMENT`, `HPA_NAME` with defaults
- [x] Document timing vars: `HPA_RAMP_SEC`, `HPA_COOLDOWN_SEC`, `HPA_POLL_SEC`
- [x] Add usage examples showing env var override syntax
