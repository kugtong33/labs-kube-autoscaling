# Story E5-S2 — HPA Evidence Artifacts

**Epic:** E5 — HPA Proof Gate
**Status:** Pending

---

## User Story

**As a** lab user,
**I want** HPA state captured to files before and after the proof loop,
**so that** I have a complete evidence bundle showing the cluster state during autoscaling.

---

## Acceptance Criteria

- `${HPA_DIR}/hpa_describe.txt` — output of `kubectl describe hpa`
- `${HPA_DIR}/hpa.yaml` — raw HPA resource YAML
- `${HPA_DIR}/top_nodes.txt` — `kubectl top nodes` output
- `${HPA_DIR}/top_pods.txt` — `kubectl top pods` output
- `${HPA_DIR}/replica_samples.csv` — timestamped replica counts (ts,replicas)
- `${HPA_DIR}/summary.txt` — PASS: baseline, max_seen, windows; or failure summary for 306

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 5.2.1 | Implement artifact collection calls in `gate_hpa_proof` (pre-load snapshots) | Pending |
| 5.2.2 | Implement `summary.txt` PASS variant writer | Pending |
| 5.2.3 | Implement `summary.txt` 306-variant writer (scale-up proved, cooldown not observed) | Pending |
