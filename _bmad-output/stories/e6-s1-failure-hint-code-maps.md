# Story E6-S1 — Failure Hint & Code Maps

**Epic:** E6 — HPA Failure Codes & Fix Dispatcher
**Status:** Done

---

## User Story

**As a** lab user,
**I want** a clear, actionable failure message for each HPA error code,
**so that** I immediately know what went wrong and what the exact fix command is.

---

## Acceptance Criteria

- `print_failure_hint <code>` emits `[HPA-30X] <title>`, Check line, Fix line, Retry line for codes 301-306
- `print_next_command_for_code <code>` returns `./scripts/fix.sh HPA-30X`
- Unknown code → `[GENERIC-<code>]` without crashing

---

## Tasks

### Task 6.1.1 — Create `scripts/lib/failure-maps.sh` — implement `print_failure_hint` with cases 301-306 + `*`
- [x] Create `scripts/lib/failure-maps.sh` with shebang (`#!/usr/bin/env bash`) and sourcing guard (`[[ -n "${_FAILURE_MAPS_SH:-}" ]] && return; _FAILURE_MAPS_SH=1`)
- [x] Define `print_failure_hint()` function accepting one positional arg `$1` (the code)
- [x] Add `case "${1}" in` block with entries for 301, 302, 303, 304, 305, 306
- [x] Case 301: print `[HPA-301] HPA resource not found`, Check: `kubectl get hpa -n ${NAMESPACE}`, Fix: `./scripts/fix.sh HPA-301`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Case 302: print `[HPA-302] Metrics server unavailable`, Check: `kubectl top nodes`, Fix: `./scripts/fix.sh HPA-302`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Case 303: print `[HPA-303] CPU requests not set on deployment`, Check: `kubectl -n ${NAMESPACE} get deploy ${APP_DEPLOYMENT} -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}'`, Fix: `./scripts/fix.sh HPA-303`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Case 304: print `[HPA-304] Load generator failed to start`, Check: `./scripts/load.sh --status`, Fix: `./scripts/fix.sh HPA-304`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Case 305: print `[HPA-305] No scale-up observed during ramp window`, Check: `cat ${HPA_DIR}/replica_samples.csv`, Fix: `./scripts/fix.sh HPA-305`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Case 306: print `[HPA-306] Cooldown not observed within window`, Check: `cat ${HPA_DIR}/replica_samples.csv`, Fix: `./scripts/fix.sh HPA-306`, Retry: `./scripts/up.sh --resume hpa_proof`
- [x] Default `*` case: print `[GENERIC-${1}] Unknown failure code` with generic retry advice — must not crash

### Task 6.1.2 — Implement `print_next_command_for_code` in same file
- [x] Define `print_next_command_for_code()` function accepting one positional arg `$1` (the code)
- [x] Add `case "${1}" in` block for 301-306: each outputs `echo "./scripts/fix.sh HPA-${1}"`
- [x] Default `*` case: output `echo "./scripts/up.sh"` as safe fallback
- [x] Ensure the function only prints the command string (no extra text); callers capture with `$(...)`

### Task 6.1.3 — Verify output format: `[HPA-30X] <title>\nCheck: ...\nFix: ...\nRetry: ...`
- [x] Each code block in `print_failure_hint` uses exactly 4 lines: title, Check, Fix, Retry
- [x] Title line format: `[HPA-30X] <descriptive title>` (no trailing colon)
- [x] Check line format: `Check: <kubectl command>`
- [x] Fix line format: `Fix: <fix.sh invocation>`
- [x] Retry line format: `Retry: ./scripts/up.sh --resume hpa_proof`
- [x] Add a blank line after the Retry line for readability
- [x] Manual smoke test: `source scripts/lib/failure-maps.sh && print_failure_hint 301` — verify output matches spec
