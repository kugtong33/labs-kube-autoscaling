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

| ID | Task | Status |
|---|---|---|
| 3.2.1 | Create `scripts/lib/scorecard.sh` — implement `print_final_scorecard` | Pending |
| 3.2.2 | Implement `print_next_action_from_scorecard` backed by Node resolver | Pending |
| 3.2.3 | Implement `__FIX_BY_CODE__` sentinel handling | Pending |
| 3.2.4 | Write `final_scorecard.json` artifact | Pending |
| 3.2.5 | Create `tests/resolver-fixtures/` with 3 JSONL fixture files + expected output assertions | Pending |
| 3.2.6 | Create `scripts/test-resolver.sh` — runs fixture tests and reports pass/fail | Pending |
