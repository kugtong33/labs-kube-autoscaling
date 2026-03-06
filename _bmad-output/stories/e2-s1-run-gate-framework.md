# Story E2-S1 — `run_gate` Framework

**Epic:** E2 — Deterministic Gate Engine
**Status:** Pending

---

## User Story

**As a** gate author,
**I want** a reusable `run_gate <name> <severity> <fn>` function,
**so that** every gate gets automatic timing, logging, artifact generation, and correct severity routing without duplicating that logic.

---

## Acceptance Criteria

- Executes `<fn>` and captures stdout/stderr to `${GATE_DIR}/<name>.log`
- Writes `${GATE_DIR}/<name>.json`: gate, severity, status (PASS/FAIL), exit_code, started_at, ended_at, duration_ms, log_file
- Appends one JSONL line to `${SCORECARD_FILE}` per gate
- CRITICAL failure: calls `print_failure_hint <code>` + `print_next_command_for_code <code>` + exits with gate exit code
- NON_CRITICAL failure: emits warn line, returns 0, pipeline continues

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 2.1.1 | Create `scripts/lib/gate-runner.sh` — implement `run_gate` function | Pending |
| 2.1.2 | Implement `duration_ms` helper using `date -u +%s%3N` (Linux) with macOS fallback | Pending |
| 2.1.3 | Implement per-gate JSON artifact writer (all required fields) | Pending |
| 2.1.4 | Implement JSONL scorecard append | Pending |
| 2.1.5 | Implement severity-aware exit routing (CRITICAL → exit; NON_CRITICAL → warn+return 0) | Pending |
