# Story E3-S2 — Scorecard Print Functions

**Epic:** E3 — Unified Outcome Resolver
**Status:** Done

---

## User Story

**As a** lab user,
**I want** a human-readable scorecard printed at the end of every run,
**so that** I always know what passed, what failed, and exactly what to do next.

---

## Acceptance Criteria

- `print_final_scorecard` prints: RUN_ID, MODE, critical N/total, non-critical N/total, first critical failure gate+code, overall status, next command
- `print_next_action_from_scorecard` calls outcome-resolver and parses key=value output
- `__FIX_BY_CODE__:<code>` sentinel in `next_command` is translated via `print_next_command_for_code`
- `final_scorecard.json` written to `${ARTIFACT_ROOT}/`
- Fixture tests confirm deterministic output for 3 canonical scorecard states

---

## Tasks

### Task 3.2.1 — Create `scripts/lib/scorecard.sh` — implement `print_final_scorecard`
- [x] Create `scripts/lib/scorecard.sh` with sourcing guard
- [x] Implement `resolve_run_outcome()`: call `outcome-resolver.js`, capture key=value output
- [x] Parse key=value lines into shell variables (`OVERALL_STATUS`, `NEXT_TYPE`, `NEXT_CMD`, `EXIT_CODE`)
- [x] Implement `print_final_scorecard()` function
- [x] Print `=== Autoscaling Lab Scorecard ===` header
- [x] Print `RUN_ID: ${RUN_ID}`
- [x] Print `MODE: ${mode}` (full_run or resume)
- [x] Count CRITICAL gates passed/total from scorecard JSONL
- [x] Count NON_CRITICAL gates passed/total
- [x] Print gate counts
- [x] Print first critical failure gate + code if present
- [x] Print `Overall status: ${OVERALL_STATUS}`
- [x] Print `Next command: ${final_cmd}`

### Task 3.2.2 — Implement `print_next_action_from_scorecard`
- [x] Define `print_next_action_from_scorecard()` function
- [x] Determine mode: `full_run` or `resume` based on `RESUME_TARGET`
- [x] Call `node - "${SCORECARD_FILE}" "${mode}" "${RUN_ID}" "${RESUME_TARGET:-}"` with resolver script
- [x] Parse output key=value pairs into local variables

### Task 3.2.3 — Implement `__FIX_BY_CODE__` sentinel handling
- [x] Check if `NEXT_CMD` starts with `__FIX_BY_CODE__:`
- [x] Extract code portion after the colon
- [x] Call `print_next_command_for_code "${code}"` and use result as final command

### Task 3.2.4 — Write `final_scorecard.json` artifact
- [x] Write JSON object to `${ARTIFACT_ROOT}/final_scorecard.json`
- [x] Include fields: `run_id`, `mode`, `overall_status`, `critical_passed`, `critical_total`, `noncritical_passed`, `noncritical_total`, `failed_gate`, `failed_code`, `next_command`

### Task 3.2.5 — Create resolver fixture files
- [x] Create `tests/resolver-fixtures/` directory
- [x] Create `fixture-blocked-critical.jsonl`: one CRITICAL gate FAIL row
- [x] Create `fixture-warnings.jsonl`: all CRITICAL gates PASS, evidence_capture FAIL
- [x] Create `fixture-success-full.jsonl`: all gates PASS
- [x] Create corresponding `.expected` files with correct key=value output for each fixture

### Task 3.2.6 — Create `scripts/test-resolver.sh`
- [x] Create `scripts/test-resolver.sh` with shebang
- [x] Loop over each fixture in `tests/resolver-fixtures/`
- [x] Run resolver with fixture JSONL as input
- [x] Compare output to `.expected` file with `diff`
- [x] Print `PASS` or `FAIL` per fixture with fixture name
- [x] Exit non-zero if any fixture fails
- [x] Print final summary: `N/N fixtures passed`
