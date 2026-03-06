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

### Task 5.2.1 — Implement artifact collection (pre-load snapshots)
- [ ] Capture `kubectl -n ${ns} describe hpa ${hpa}` → `${HPA_DIR}/hpa_describe.txt`
- [ ] Capture `kubectl -n ${ns} get hpa ${hpa} -o yaml` → `${HPA_DIR}/hpa.yaml`
- [ ] Capture `kubectl top nodes` → `${HPA_DIR}/top_nodes.txt`
- [ ] Capture `kubectl -n ${ns} top pods` → `${HPA_DIR}/top_pods.txt`
- [ ] All captures wrapped in `|| true` to avoid blocking proof on capture failure

### Task 5.2.2 — Implement `summary.txt` PASS variant writer
- [ ] Write `PASS` status line
- [ ] Write `baseline_replicas=${baseline}`
- [ ] Write `max_replicas_seen=${max_seen}`
- [ ] Write `scale_up_window_sec=${ramp_sec}`
- [ ] Write `cooldown_window_sec=${cool_sec}`
- [ ] Write `samples_file=${HPA_DIR}/replica_samples.csv`

### Task 5.2.3 — Implement `summary.txt` 306-variant writer
- [ ] Write `HPA scale-up proved (baseline=${baseline}, max_seen=${max_seen})`
- [ ] Write `Cooldown not observed within ${cool_sec}s`
