#!/usr/bin/env node
// scripts/lib/outcome-resolver.js
// Reads scorecard.jsonl and deterministically computes outcome + next action.
//
// Usage:
//   node scripts/lib/outcome-resolver.js <scoreFile> <mode> <runId> [resumeTarget]
//
// Emits KEY=VALUE lines to stdout. The shell scorecard.sh reads these.

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------
const [, , scoreFile, mode = 'full_run', runId = 'unknown', resumeTarget = ''] = process.argv;

// ---------------------------------------------------------------------------
// out(k, v) — emit KEY=VALUE to stdout
// ---------------------------------------------------------------------------
function out(k, v) {
  process.stdout.write(`${k}=${v}\n`);
}

// ---------------------------------------------------------------------------
// Scorecard parsing (tamper-tolerant)
// ---------------------------------------------------------------------------
let rows = [];

try {
  const raw = fs.readFileSync(scoreFile, 'utf8');
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      rows.push(JSON.parse(trimmed));
    } catch {
      // Skip malformed lines silently
    }
  }
} catch {
  // Missing or unreadable file
  out('OVERALL_STATUS', 'UNKNOWN_NO_SCORECARD');
  out('NEXT_TYPE', 'CMD');
  out('NEXT_CMD', `./scripts/validate.sh --run-id ${runId}`);
  out('EXIT_CODE', '0');
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Build gate map (last row wins for any duplicate gate name)
// ---------------------------------------------------------------------------
const gateMap = new Map();
for (const row of rows) {
  if (row.gate) gateMap.set(row.gate, row);
}

// ---------------------------------------------------------------------------
// CRITICAL gate priority evaluation
// Order is fixed; first FAIL in this list blocks the run.
// ---------------------------------------------------------------------------
const CRITICAL_PRIORITY = [
  'bootstrap_gate',
  'bootstrap_integrity',
  'reachability_gate',
  'hpa_proof',
];

let blockedGate = null;
let blockedCode = 0;

for (const gateName of CRITICAL_PRIORITY) {
  const row = gateMap.get(gateName);
  if (!row) continue; // gate not yet run (skip)
  if (row.status === 'FAIL') {
    blockedGate = gateName;
    blockedCode = typeof row.exit_code === 'number' ? row.exit_code : 1;
    break;
  }
}

// ---------------------------------------------------------------------------
// Write outcome.json artifact
// ---------------------------------------------------------------------------
const artifactRoot = path.dirname(scoreFile); // artifacts/<runId>
const outcomeData = {
  run_id: runId,
  mode,
  resume_target: resumeTarget || null,
  critical_failure_gate: blockedGate,
  critical_failure_code: blockedCode || null,
  rows_parsed: rows.length,
};
try {
  fs.writeFileSync(path.join(artifactRoot, 'outcome.json'), JSON.stringify(outcomeData, null, 2) + '\n');
} catch {
  // Non-fatal — artifact write failure should not change the outcome
}

// ---------------------------------------------------------------------------
// Branch: BLOCKED_CRITICAL_FAILURE
// ---------------------------------------------------------------------------
if (blockedGate !== null) {
  out('OVERALL_STATUS', 'BLOCKED_CRITICAL_FAILURE');
  out('NEXT_TYPE', 'FIX');
  out('NEXT_CMD', `__FIX_BY_CODE__:${blockedCode}`);
  out('EXIT_CODE', String(blockedCode));
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Branch: LEARNING_READY_WITH_WARNINGS (NON_CRITICAL evidence failure)
// ---------------------------------------------------------------------------
const evidenceRow = gateMap.get('evidence_capture');
const evidenceFailed =
  evidenceRow &&
  evidenceRow.severity === 'NON_CRITICAL' &&
  evidenceRow.status === 'FAIL';

if (evidenceFailed) {
  const statusSuffix = mode === 'resume' ? 'RESUME' : 'FULL';
  out('OVERALL_STATUS', `LEARNING_READY_WITH_WARNINGS_${statusSuffix}`);
  out('NEXT_TYPE', 'CMD');
  const resumeFlag = mode === 'resume' ? ' --from-resume' : '';
  out('NEXT_CMD', `./scripts/collect-evidence.sh --run-id ${runId}${resumeFlag}`);
  out('EXIT_CODE', '0');
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Branch: SUCCESS
// ---------------------------------------------------------------------------
const statusSuffix = mode === 'resume' ? 'RESUME' : 'FULL';
out('OVERALL_STATUS', `SUCCESS_${statusSuffix}`);
out('NEXT_TYPE', 'CMD');
if (mode === 'resume') {
  out('NEXT_CMD', `./scripts/down.sh --run-id ${runId} --preserve-artifacts`);
} else {
  out('NEXT_CMD', `./scripts/down.sh --run-id ${runId}`);
}
out('EXIT_CODE', '0');
process.exit(0);
