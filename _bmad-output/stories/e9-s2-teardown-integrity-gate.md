# Story E9-S2 — Teardown & Integrity Gate

**Epic:** E9 — Evidence Capture & Teardown
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** `./scripts/down.sh` to cleanly remove all lab resources and verify re-run is possible,
**so that** every lifecycle ends reproducibly.

---

## Acceptance Criteria

- `down.sh` deletes namespace (`kubectl delete ns autoscaling-lab`)
- `down.sh` optionally deletes KinD cluster (`--delete-cluster` flag or default behavior TBD)
- `--preserve-artifacts` skips artifact directory deletion
- `gate_teardown_integrity` (NON_CRITICAL): verifies cluster still listed or namespace deleted
- After teardown, `up.sh` can be re-run cleanly

---

## Tasks

### Task 9.2.1 — Create `scripts/down.sh` with `--run-id`, `--preserve-artifacts`, `--delete-cluster` arg parsing
- [ ] Create `scripts/down.sh` with shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- [ ] Source `scripts/lib/config.sh` and `scripts/lib/gate-teardown.sh`
- [ ] Parse `--run-id <id>`: set `RUN_ID="${2}"` and export; shift 2
- [ ] Parse `--preserve-artifacts`: set `PRESERVE_ARTIFACTS=1`; shift
- [ ] Parse `--delete-cluster`: set `DELETE_CLUSTER=1`; shift
- [ ] Default: `PRESERVE_ARTIFACTS=0`, `DELETE_CLUSTER=0`
- [ ] After parsing: call `teardown_namespace`; if `DELETE_CLUSTER=1` call `teardown_cluster`; call `gate_teardown_integrity` (non-critical)
- [ ] Print summary: `Teardown complete. Re-run: ./scripts/up.sh`

### Task 9.2.2 — Implement namespace deletion with confirmation output
- [ ] Define `teardown_namespace()` function in `scripts/lib/gate-teardown.sh` (or inline in `down.sh`)
- [ ] Print `Deleting namespace ${NAMESPACE}...`
- [ ] Run `kubectl delete ns "${NAMESPACE}" --timeout=60s` with `|| true` to avoid crashing if namespace already gone
- [ ] Verify deletion: `kubectl get ns "${NAMESPACE}" 2>/dev/null && echo "Warning: namespace still exists" || echo "Namespace deleted: ${NAMESPACE}"`
- [ ] Also stop any running load generator: `./scripts/load.sh --stop 2>/dev/null || true`
- [ ] If `PRESERVE_ARTIFACTS=0`: remove `.state/` directory contents: `rm -f .state/last_run_id .state/load.pid .state/env-overrides`
- [ ] Print `Namespace teardown: done`

### Task 9.2.3 — Implement optional KinD cluster deletion
- [ ] Define `teardown_cluster()` function
- [ ] Check cluster exists first: `kind get clusters 2>/dev/null | grep -q "autoscaling-lab"` — skip if not found
- [ ] Print `Deleting KinD cluster autoscaling-lab...`
- [ ] Run `kind delete cluster --name autoscaling-lab`
- [ ] Verify: `kind get clusters 2>/dev/null | grep -q "autoscaling-lab" && echo "Warning: cluster still listed" || echo "Cluster deleted"`
- [ ] Print `Cluster teardown: done`

### Task 9.2.4 — Implement `gate_teardown_integrity` in `scripts/lib/gate-teardown.sh`
- [ ] Create `scripts/lib/gate-teardown.sh` with shebang and sourcing guard
- [ ] Define `gate_teardown_integrity()` function
- [ ] Check namespace is gone: `kubectl get ns "${NAMESPACE}" 2>/dev/null` should return non-zero; log result
- [ ] Check cluster is still accessible (or deleted, depending on mode): `kubectl cluster-info --context kind-autoscaling-lab >/dev/null 2>&1`
- [ ] Verify `up.sh` can be re-run: check that `kind get clusters` does not conflict with a fresh create (cluster absent OR cluster present and healthy)
- [ ] Write integrity result to `${ARTIFACT_ROOT}/teardown-integrity.json`: `{"namespace_deleted":true/false,"cluster_status":"present|deleted","rerun_ready":true/false}`
- [ ] Return 0 in all cases (NON_CRITICAL gate — result is informational only)
