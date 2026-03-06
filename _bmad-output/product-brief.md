# Product Brief
## Local Kubernetes Autoscaling Lab

**Version:** 1.0
**Date:** 2026-03-06
**Status:** Approved for implementation
**Source:** Brainstorming session outputs (`_bmad-output/brainstorming/`)

---

## 1. Problem Statement

Kubernetes Horizontal Pod Autoscaling (HPA) is a core production concept, but developers and learners have no reliable, self-contained way to observe and prove autoscaling behavior on their own machine. Existing guides assume cloud environments, manual kubectl steps, or pre-built tooling whose results are hard to reproduce. There is no lab that:

- Runs entirely on a local laptop with KinD
- Provisions, proves, and tears down autoscaling in a single command flow
- Gives learners deterministic feedback when something goes wrong
- Produces evidence artifacts suitable for review or self-assessment

---

## 2. Goal

Build a **reproducible, self-contained local Kubernetes autoscaling lab** that:

1. Provisions a KinD cluster with a sample app and metrics-server
2. Generates synthetic load and proves HPA scale-up and cooldown behavior
3. Collects evidence (command output, replica samples CSV, checklist)
4. Guides the learner to recovery when any step fails
5. Tears down cleanly and is re-runnable from scratch

---

## 3. Target Audience

| Audience | Profile | Priority |
|---|---|---|
| **A — Beginner learner** | Knows Docker, new to Kubernetes; wants first HPA success in under 15 minutes | Primary (50%) |
| **B — Intermediate practitioner** | Knows Kubernetes basics; wants to observe HPA tuning and failure and recovery | Primary (30%) |
| **C — Advanced user** | Wants to adapt the lab, customize profiles, or use it as a teaching base | Optional (20%) |

**Design focus:** Audiences A and B must succeed on the golden path. Audience C is served by the configuration surface and documented extension points.

---

## 4. Success Criteria

| Criterion | Measure |
|---|---|
| Golden path completes | `./scripts/up.sh` runs to `SUCCESS_FULL` status |
| HPA proof demonstrated | Replicas increase above baseline under load; decrease after load stops |
| First success achievable | Audience A completes golden path in ≤ 15 minutes on first attempt |
| Self-recoverable | Every failure produces a single deterministic `next_command` |
| Evidence captured | `replica_samples.csv` and `evidence-checklist.md` present after every successful run |
| Idempotent | Re-running `up.sh` after `down.sh` produces same result |
| Cross-OS | Runs on Linux and macOS without modification |

---

## 5. Scope

### In Scope (v1)

- Single-node KinD cluster
- Toolchain: `bash`, `node`, `docker`, `kind` only
- NodePort service exposure (browser-accessible)
- HPA based on CPU utilization
- Dual app mode: landing page and single-endpoint API (switchable)
- Dual load mode: in-cluster pod and host-side process (switchable)
- Three replica profiles: `tiny` (max 5), `balanced` (max 7), `stretch` (max 10)
- Gate-based orchestration with CRITICAL/NON_CRITICAL severity
- HPA failure codes 301–306 with deterministic fix dispatcher
- Artifact generation: per-gate logs, scorecard JSONL, HPA evidence, final scorecard JSON
- Resume path: `up.sh --resume hpa_proof` after a fix
- Linux + macOS support

### Out of Scope (v1)

- Multi-node KinD clusters
- VPA (may be added in observe-only mode in v2)
- Cloud environments (EKS, GKE, AKS)
- Windows support
- Ingress or LoadBalancer service types
- Persistent storage or stateful workloads
- RBAC or security hardening
- CI/CD pipeline integration

---

## 6. Hard Constraints

| Constraint | Rationale |
|---|---|
| Toolchain: `bash`, `node`, `docker`, `kind` only | Keeps prerequisites minimal; reduces learner cognitive load |
| Single-node KinD only | Predictable local resource usage; reproducible |
| NodePort service exposure only | Simplest browser-reachable path; no Ingress complexity |
| Linux + macOS support in v1 | Covers the primary learner machine set |
| Artifacts must be generated per run | Evidence is non-optional for proof |
| 3 auto-fix attempts max per failure code | Prevents infinite loops; forces escalation to user |

---

## 7. Flexible Constraints (Defaults with Override)

| Item | Default | Override |
|---|---|---|
| Sample API shape | Single endpoint | Keep simple; doc-linkable to extensions |
| Load test tool runs as pod | `LOAD_MODE=pod` | Switchable to `host` mode |
| Full setup time | Target ≤ 10 minutes | Flexible if image cache is cold |
| No internet after initial pull | Preferred | Not enforced in v1 |

---

## 8. Delivery Model — D3

The selected delivery model is **D3: Switchable Workload + Profile Ladder + Dual Load Mode**.

| Parameter | Values | Default |
|---|---|---|
| `APP_MODE` | `landing` \| `api` | `landing` |
| `LOAD_MODE` | `pod` \| `host` | `pod` |
| `PROFILE` | `tiny` \| `balanced` \| `stretch` | `tiny` |
| `PROFILE` → `maxReplicas` | 5 \| 7 \| 10 | 5 |

All parameters are environment variables. One command surface (`up / load / down / reset`) works across all variants.

---

## 9. Gate Architecture

### Primary Gate Sequence (Full Run)

| Order | Gate | Severity | Pass Condition | On Fail |
|---|---|---|---|---|
| 1 | Bootstrap | CRITICAL | Cluster + namespace + workloads + metrics baseline ready | Exit fast with mapped fix command |
| 2 | Reachability | CRITICAL | NodePort URL returns HTTP 200 | Exit fast with mapped fix command |
| 3 | HPA Proof | CRITICAL | Replicas increase above baseline under load; cooldown observed after load stops | Exit fast with HPA-30X fix command |
| 4 | Evidence Capture | NON_CRITICAL | Output + CSV + checklist artifacts present | Warn; suggest `collect-evidence.sh` |
| 5 | Teardown Integrity | NON_CRITICAL | Cleanup completes; re-run possible | Warn; summarize |

### Resume Sequence (`up.sh --resume hpa_proof`)

| Order | Gate | Purpose |
|---|---|---|
| 1 | Bootstrap Integrity | Read-only: confirm cluster/app still valid |
| 2 | Reachability | Confirm browser path still works |
| 3 | HPA Proof | Re-run autoscaling proof |
| 4 | Evidence Capture | Refresh evidence artifacts |

---

## 10. HPA Failure Model

### Failure Codes

| Code | Meaning | Deterministic Fix |
|---|---|---|
| HPA-301 | HPA object missing | `./scripts/fix.sh HPA-301` |
| HPA-302 | Metrics server unavailable | `./scripts/fix.sh HPA-302` |
| HPA-303 | CPU resource requests missing from deployment | `./scripts/fix.sh HPA-303` |
| HPA-304 | Load generator failed to start | `./scripts/fix.sh HPA-304` |
| HPA-305 | No scale-up observed within ramp window | `./scripts/fix.sh HPA-305` |
| HPA-306 | Cooldown scale-down not observed | `./scripts/fix.sh HPA-306` |

### Fix Strategy

Each code has a 3-attempt escalation ladder:
- **Attempt 1 (Canonical):** Standard fix — apply known-good resource
- **Attempt 2 (Tuned):** Adjusted parameters or restarted component
- **Attempt 3 (Fallback):** Minimal/safe preset that guarantees observable behavior

After any fix: `./scripts/up.sh --resume hpa_proof`

---

## 11. Outcome Model

Every run produces a deterministic `overall_status` and `next_command` via a single Node-based outcome resolver:

| Condition | Status | Next Command |
|---|---|---|
| Any CRITICAL gate failed | `BLOCKED_CRITICAL_FAILURE` | `./scripts/fix.sh HPA-30X` |
| No CRITICAL failures, evidence failed | `LEARNING_READY_WITH_WARNINGS_FULL` | `./scripts/collect-evidence.sh` |
| All gates passed (full run) | `SUCCESS_FULL` | `./scripts/down.sh --run-id <id>` |
| All gates passed (resume) | `SUCCESS_RESUME` | `./scripts/down.sh --run-id <id> --preserve-artifacts` |

---

## 12. Artifact Contract

Every run produces artifacts under `artifacts/<run-id>/`:

```
artifacts/<run-id>/
├── scorecard.jsonl          # One JSONL line per gate
├── final_scorecard.json     # Resolved overall outcome
├── timeline.log             # Gate sequence log
├── gates/
│   ├── bootstrap_gate.json
│   ├── bootstrap_gate.log
│   ├── reachability_gate.json
│   ├── reachability_gate.log
│   ├── hpa_proof.json
│   ├── hpa_proof.log
│   └── evidence_capture.json
├── hpa/
│   ├── hpa_describe.txt
│   ├── hpa.yaml
│   ├── top_nodes.txt
│   ├── top_pods.txt
│   ├── replica_samples.csv
│   └── summary.txt
└── evidence-checklist.md
```

---

## 13. Non-Functional Requirements

| Requirement | Target |
|---|---|
| Idempotency | All scripts re-runnable without manual cleanup between runs |
| Script portability | POSIX-compatible bash; targets bash 3.2+ (macOS default) |
| Memory safety | `tiny` profile works on 2GB available RAM; `stretch` requires 8GB |
| Startup time | Golden path (warm cache): ≤ 10 minutes |
| First-success time | Audience A: ≤ 15 minutes total including reading the quick-start guide |
| Artifact isolation | Each run produces its own timestamped artifact directory |
| Failure recoverability | No run failure leaves cluster in a state that blocks re-run |

---

## 14. Out-of-scope Clarifications

- **VPA:** Not in v1. May be added as an observe-only overlay in v2.
- **Windows:** Not supported in v1. WSL2 users may attempt at their own risk.
- **Ingress/DNS:** NodePort is the deliberate pedagogical choice; no Ingress needed.
- **Real load testing tools (k6, Locust):** Not required. A pod-mode curl loop is sufficient to prove HPA behavior.

---

*Product Brief approved for implementation. All epics and stories derived from this document.*
