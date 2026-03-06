# Story E6-S1 — Failure Hint & Code Maps

**Epic:** E6 — HPA Failure Codes & Fix Dispatcher
**Status:** Pending

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

| ID | Task | Status |
|---|---|---|
| 6.1.1 | Create `scripts/lib/failure-maps.sh` — implement `print_failure_hint` with cases 301-306 + `*` | Pending |
| 6.1.2 | Implement `print_next_command_for_code` in same file | Pending |
| 6.1.3 | Verify output format: `[HPA-30X] <title>\nCheck: ...\nFix: ...\nRetry: ...` | Pending |
