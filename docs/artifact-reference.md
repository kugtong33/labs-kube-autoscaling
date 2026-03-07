# Artifact Reference

Every run of `./scripts/up.sh` writes artifacts to `artifacts/<run-id>/`. Use `--run-id <id>` on any script to target a specific run.

---

## Artifact Tree

```
artifacts/
└── <run-id>/                          # e.g. 20240315-142301
    │
    ├── scorecard.jsonl                # one JSONL row per gate result
    ├── final_scorecard.json           # aggregated run outcome
    ├── evidence-checklist.md          # reviewer-ready checklist
    ├── teardown-integrity.json        # post-teardown state
    ├── timeline.log                   # timestamped gate sequence log
    │
    ├── gates/                         # per-gate log + JSON artifacts
    │   ├── bootstrap_gate.log
    │   ├── bootstrap_gate.json
    │   ├── reachability_gate.log
    │   ├── reachability_gate.json
    │   ├── hpa_proof.log
    │   ├── hpa_proof.json
    │   └── evidence_capture.log
    │
    ├── hpa/                           # HPA proof artifacts
    │   ├── hpa_describe.txt           # kubectl describe hpa (pre-load)
    │   ├── hpa.yaml                   # raw HPA resource YAML
    │   ├── top_nodes.txt              # kubectl top nodes (pre-load)
    │   ├── top_pods.txt               # kubectl top pods (pre-load)
    │   ├── replica_samples.csv        # timestamped replica counts
    │   └── summary.txt                # proof verdict
    │
    ├── evidence/                      # post-proof cluster snapshots
    │   ├── all-resources.txt          # kubectl get all -n <ns>
    │   ├── hpa-describe.txt           # kubectl describe hpa (post-proof)
    │   ├── replica_samples.csv        # copy of hpa/replica_samples.csv
    │   └── events.txt                 # sorted namespace events
    │
    └── fix/                           # fix attempt artifacts (if fix.sh was run)
        ├── HPA-301.log
        ├── HPA-301.json
        └── ...
```

---

## File Descriptions

### `scorecard.jsonl`

One JSON line per gate result, appended as each gate completes.

```jsonc
{"gate":"bootstrap_gate","severity":"CRITICAL","status":"PASS","exit_code":0,"started_at":"2024-03-15T14:23:01Z","duration_ms":45231}
{"gate":"reachability_gate","severity":"CRITICAL","status":"PASS","exit_code":0,"started_at":"2024-03-15T14:24:05Z","duration_ms":1203}
```

Fields: `gate`, `severity` (`CRITICAL`|`NON_CRITICAL`), `status` (`PASS`|`FAIL`), `exit_code`, `started_at`, `duration_ms`.

---

### `final_scorecard.json`

Aggregated run outcome written after all gates complete.

```jsonc
{
  "run_id": "20240315-142301",
  "mode": "full_run",               // or "resume"
  "overall_status": "LEARNING_COMPLETE",
  "critical_passed": 4,
  "critical_total": 4,
  "noncritical_passed": 1,
  "noncritical_total": 1,
  "failed_gate": null,
  "failed_code": null,
  "next_command": "./scripts/down.sh"
}
```

---

### `hpa/hpa_describe.txt`

Raw output of `kubectl describe hpa <name> -n <ns>` captured before load starts. Shows current min/max replicas, CPU target, and current utilization at proof time.

---

### `hpa/hpa.yaml`

Raw HPA resource YAML as it exists in the cluster at proof time (`kubectl get hpa -o yaml`). Useful for verifying the exact configuration that was tested.

---

### `hpa/top_nodes.txt`

Output of `kubectl top nodes` captured before load starts. Shows node CPU and memory usage — baseline context for the proof.

---

### `hpa/top_pods.txt`

Output of `kubectl top pods -n <ns>` captured before load starts. Confirms metrics-server is serving pod-level data.

---

### `hpa/replica_samples.csv`

Timestamped replica count readings taken every `HPA_POLL_SEC` seconds throughout both the ramp and cooldown phases.

```
ts,replicas
2024-03-15T14:25:00Z,1
2024-03-15T14:25:10Z,1
2024-03-15T14:25:20Z,3
2024-03-15T14:25:30Z,5
2024-03-15T14:25:40Z,5
2024-03-15T14:40:00Z,2
2024-03-15T14:40:10Z,1
```

---

### `hpa/summary.txt`

Proof verdict. PASS format:

```
PASS
baseline_replicas=1
max_replicas_seen=5
scale_up_window_sec=180
cooldown_window_sec=240
samples_file=artifacts/20240315-142301/hpa/replica_samples.csv
```

HPA-306 (scale-up proved, cooldown not observed) format:

```
HPA scale-up proved (baseline=1, max_seen=5)
Cooldown not observed within 240s
```

---

### `evidence/all-resources.txt`

Output of `kubectl get all -n <ns>` captured after the proof loop. Shows all pods, deployments, services, and HPAs in their post-proof state.

---

### `evidence/events.txt`

Kubernetes events from the namespace sorted by creation timestamp. Useful for diagnosing scheduling delays, OOMKills, or image pull failures that may have affected the proof.

---

### `evidence-checklist.md`

Reviewer-ready checklist generated after evidence capture. Example:

```markdown
# Evidence Checklist — Run ID: 20240315-142301

Generated: 2024-03-15T14:45:00Z

- [x] all-resources.txt captured
- [x] hpa-describe.txt captured
- [x] replica_samples.csv present
- [x] events.txt captured
- [ ] Screenshot of HPA scale-up graph (manual step)
- [ ] Reviewer sign-off
```

---

### `teardown-integrity.json`

Written by `gate_teardown_integrity` after `down.sh` runs.

```jsonc
{
  "namespace_deleted": true,
  "cluster_status": "present",   // or "deleted" if --delete-cluster was used
  "rerun_ready": true
}
```

`rerun_ready: true` means the namespace is gone and a fresh `./scripts/up.sh` will not conflict.

---

### `fix/<code>.log` and `fix/<code>.json`

Written by `./scripts/fix.sh HPA-30X` for each fix attempt.

Log format (one line per attempt):
```
[2024-03-15T14:30:00Z] code=HPA-302 status=ok attempt=1 note=metrics-server applied and rolled out
```

JSON format:
```jsonc
{
  "code": "HPA-302",
  "status": "ok",          // or "fail" or "bounded_stop"
  "note": "metrics-server applied and rolled out",
  "run_id": "20240315-142301",
  "attempt": 1
}
```

If all 3 attempts are exhausted, a `fix-escalation-<code>.tar.gz` bundle is created in `artifacts/<run-id>/` containing all log and JSON files for that code.
