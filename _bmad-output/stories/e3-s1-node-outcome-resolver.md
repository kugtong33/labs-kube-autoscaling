# Story E3-S1 — Node Outcome Resolver

**Epic:** E3 — Unified Outcome Resolver
**Status:** Done

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

### Task 3.1.1 — Create `scripts/lib/outcome-resolver.js`
- [x] Create file as an inline Node script (executable via `node - args <<'NODE' ... NODE`)
- [x] Accept argv: `scoreFile`, `mode`, `runId`, `resumeTarget`
- [x] Define `out(k, v)` helper to emit `KEY=VALUE` lines to stdout
- [x] Read scorecard file with `fs.readFileSync`
- [x] Split on newlines and filter empty lines
- [x] Parse each line with `JSON.parse`

### Task 3.1.2 — Implement gate priority evaluation
- [x] Define priority array: `['bootstrap_gate','bootstrap_integrity','reachability_gate','hpa_proof']`
- [x] Build `Map` of gate name → row object from parsed scorecard rows
- [x] Iterate priority array in order
- [x] Detect first CRITICAL gate with `status === 'FAIL'`
- [x] If found: emit `NEXT_TYPE=FIX`, `EXIT_CODE=<exit_code>`, `OVERALL_STATUS=BLOCKED_CRITICAL_FAILURE`

### Task 3.1.3 — Implement `LEARNING_READY_WITH_WARNINGS` branch
- [x] Look up `evidence_capture` row in map
- [x] Check if `severity === 'NON_CRITICAL'` and `status === 'FAIL'`
- [x] If mode is `full_run`: emit `OVERALL_STATUS=LEARNING_READY_WITH_WARNINGS_FULL`
- [x] If mode is `resume`: emit `OVERALL_STATUS=LEARNING_READY_WITH_WARNINGS_RESUME`
- [x] Emit `NEXT_CMD=./scripts/collect-evidence.sh --run-id <runId>` (append `--from-resume` for resume mode)

### Task 3.1.4 — Implement `SUCCESS` branch
- [x] If no CRITICAL failures and no evidence failure: emit success
- [x] If mode is `full_run`: emit `OVERALL_STATUS=SUCCESS_FULL`, `NEXT_CMD=./scripts/down.sh --run-id <runId>`
- [x] If mode is `resume`: emit `OVERALL_STATUS=SUCCESS_RESUME`, `NEXT_CMD=./scripts/down.sh --run-id <runId> --preserve-artifacts`
- [x] Emit `NEXT_TYPE=CMD` for both success paths

### Task 3.1.5 — Implement tamper-tolerant scorecard parsing
- [x] Wrap each `JSON.parse` call in `try/catch`
- [x] Skip malformed lines silently (continue loop)
- [x] Wrap entire file read in try/catch
- [x] On missing/unreadable file: emit `OVERALL_STATUS=UNKNOWN_NO_SCORECARD`
- [x] Emit fallback `NEXT_CMD=./scripts/validate.sh --run-id <runId>`
- [x] `process.exit(0)` after fallback output
