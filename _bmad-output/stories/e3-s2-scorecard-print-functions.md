# Story E3-S2 — Scorecard Print Functions

**Epic:** E3 — Unified Outcome Resolver
**Status:** Pending

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
- [ ] Create `scripts/lib/scorecard.sh` with sourcing guard
- [ ] Implement `resolve_run_outcome()`: call `outcome-resolver.js`, capture key=value output
- [ ] Parse key=value lines into shell variables (`OVERALL_STATUS`, `NEXT_TYPE`, `NEXT_CMD`, `EXIT_CODE`)
- [ ] Implement `print_final_scorecard()` function
- [ ] Print `=== Autoscaling Lab Scorecard ===` header
- [ ] Print `RUN_ID: ${RUN_ID}`
- [ ] Print `MODE: ${mode}` (full_run or resume)
- [ ] Count CRITICAL gates passed/total from scorecard JSONL
- [ ] Count NON_CRITICAL gates passed/total
- [ ] Print gate counts
- [ ] Print first critical failure gate + code if present
- [ ] Print `Overall status: ${OVERALL_STATUS}`
- [ ] Print `Next command: ${final_cmd}`

### Task 3.2.2 — Implement `print_next_action_from_scorecard`
- [ ] Define `print_next_action_from_scorecard()` function
- [ ] Determine mode: `full_run` or `resume` based on `RESUME_TARGET`
- [ ] Call `node - "${SCORECARD_FILE}" "${mode}" "${RUN_ID}" "${RESUME_TARGET:-}"` with resolver script
- [ ] Parse output key=value pairs into local variables

### Task 3.2.3 — Implement `__FIX_BY_CODE__` sentinel handling
- [ ] Check if `NEXT_CMD` starts with `__FIX_BY_CODE__:`
- [ ] Extract code portion after the colon
- [ ] Call `print_next_command_for_code "${code}"` and use result as final command

### Task 3.2.4 — Write `final_scorecard.json` artifact
- [ ] Write JSON object to `${ARTIFACT_ROOT}/final_scorecard.json`
- [ ] Include fields: `run_id`, `mode`, `overall_status`, `critical_passed`, `critical_total`, `noncritical_passed`, `noncritical_total`, `failed_gate`, `failed_code`, `next_command`

### Task 3.2.5 — Create resolver fixture files
- [ ] Create `tests/resolver-fixtures/` directory
- [ ] Create `fixture-blocked-critical.jsonl`: one CRITICAL gate FAIL row
- [ ] Create `fixture-warnings.jsonl`: all CRITICAL gates PASS, evidence_capture FAIL
- [ ] Create `fixture-success-full.jsonl`: all gates PASS
- [ ] Create corresponding `.expected` files with correct key=value output for each fixture

### Task 3.2.6 — Create `scripts/test-resolver.sh`
- [ ] Create `scripts/test-resolver.sh` with shebang
- [ ] Loop over each fixture in `tests/resolver-fixtures/`
- [ ] Run resolver with fixture JSONL as input
- [ ] Compare output to `.expected` file with `diff`
- [ ] Print `PASS` or `FAIL` per fixture with fixture name
- [ ] Exit non-zero if any fixture fails
- [ ] Print final summary: `N/N fixtures passed`
