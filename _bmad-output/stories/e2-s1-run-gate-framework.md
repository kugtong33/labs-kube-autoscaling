# Story E2-S1 — `run_gate` Framework

**Epic:** E2 — Deterministic Gate Engine
**Status:** Done

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

### Task 2.1.1 — Create `scripts/lib/gate-runner.sh` — implement `run_gate`
- [x] Create file with shebang and sourcing guard
- [x] Define `run_gate <gate_name> <severity> <fn>` function signature
- [x] Set `gate_log` and `gate_json` path variables from `${GATE_DIR}`
- [x] Capture `start_ts` before executing function
- [x] Execute `${fn}` redirecting stdout+stderr to `${gate_log}`
- [x] Capture exit code `rc=$?`
- [x] Set `status=PASS` if `rc -eq 0`, else `status=FAIL`
- [x] Capture `end_ts` after execution

### Task 2.1.2 — Implement `duration_ms` helper
- [x] Define `duration_ms <start_ts> <end_ts>` function
- [x] Linux path: use `date +%s%3N` for millisecond timestamps
- [x] macOS fallback: use `python3 -c 'import time; print(int(time.time()*1000))'`
- [x] Compute and echo difference in milliseconds

### Task 2.1.3 — Implement per-gate JSON artifact writer
- [x] Write `gate` field to `${gate_json}`
- [x] Write `severity` field
- [x] Write `status` field (PASS/FAIL)
- [x] Write `exit_code` field (integer)
- [x] Write `started_at` field (ISO UTC timestamp)
- [x] Write `ended_at` field (ISO UTC timestamp)
- [x] Write `duration_ms` field (integer)
- [x] Write `log_file` field (absolute path)

### Task 2.1.4 — Implement JSONL scorecard append
- [x] Format one-line JSON: `{"gate":"...","severity":"...","status":"...","exit_code":N}`
- [x] Append to `${SCORECARD_FILE}` with `>>`

### Task 2.1.5 — Implement severity-aware exit routing
- [x] On CRITICAL + failure: call `print_failure_hint "${rc}"`
- [x] On CRITICAL + failure: call `print_next_command_for_code "${rc}"`
- [x] On CRITICAL + failure: `exit "${rc}"`
- [x] On NON_CRITICAL + failure: call `warn "NON_CRITICAL gate failed: ${gate_name} (code ${rc})"`
- [x] On NON_CRITICAL + failure: `return 0`
- [x] On pass: `return 0`
