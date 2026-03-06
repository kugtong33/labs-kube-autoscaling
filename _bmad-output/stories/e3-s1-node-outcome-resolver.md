# Story E3-S1 — Node Outcome Resolver

**Epic:** E3 — Unified Outcome Resolver
**Status:** Pending

---

## User Story

**As a** lab runner,
**I want** a Node.js module that reads `scorecard.jsonl` and deterministically computes outcome and next action,
**so that** the scorecard and next_command output can never diverge.

---

## Acceptance Criteria

- Reads `scorecard.jsonl`; handles missing/corrupt file → status `UNKNOWN_NO_SCORECARD`, next: `./scripts/validate.sh --run-id <id>`
- Evaluates CRITICAL gates in fixed priority: `bootstrap_gate → bootstrap_integrity → reachability_gate → hpa_proof`
- First CRITICAL FAIL → `BLOCKED_CRITICAL_FAILURE`; emits `NEXT_TYPE=FIX`, `EXIT_CODE=<n>`
- Evidence NON_CRITICAL FAIL → `LEARNING_READY_WITH_WARNINGS_FULL` or `_RESUME`
- All gates pass → `SUCCESS_FULL` or `SUCCESS_RESUME`
- Differentiates `full_run` vs `resume` mode via argv
- Writes `outcome.json` to `${ARTIFACT_ROOT}/`

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 3.1.1 | Create `scripts/lib/outcome-resolver.js` as an inline Node script (stdin-passable) | Pending |
| 3.1.2 | Implement gate priority evaluation: fixed array, `Map` lookup, first-CRITICAL-fail detection | Pending |
| 3.1.3 | Implement `LEARNING_READY_WITH_WARNINGS` branch with `FULL` vs `RESUME` mode distinction | Pending |
| 3.1.4 | Implement `SUCCESS_FULL` / `SUCCESS_RESUME` branch with correct `down.sh` variant | Pending |
| 3.1.5 | Implement tamper-tolerant scorecard parsing (try/catch per line; skip malformed) | Pending |
