# Story E10-S1 — Quick-Start & Concepts Docs

**Epic:** E10 — Documentation & Learner Experience
**Status:** Pending

---

## User Story

**As a** beginner learner (Audience A),
**I want** a quick-start guide that gets me to a successful HPA proof in under 15 minutes,
**so that** I build confidence before going deeper.

---

## Acceptance Criteria

- `docs/quick-start.md`: prerequisites checklist → `up.sh` → observe scorecard → `down.sh` — minimal prose, commands-first
- `docs/concepts.md`: Docker-to-K8s bridge framing, two-layer mental model (app → orchestration → behavior)
- Both docs tested against a fresh-install path by a human reviewer

---

## Tasks

### Task 10.1.1 — Write `docs/quick-start.md`: prerequisites, single command flow, how to read scorecard
- [ ] Create `docs/quick-start.md`
- [ ] Open with a **Prerequisites** checklist table: tool name, minimum version, install link — cover `docker`, `kind`, `kubectl`, `node`, `bash`, `curl`
- [ ] Add **Quick Start** section with numbered steps:
  - [ ] Step 1: Clone the repo (or note it is already cloned)
  - [ ] Step 2: `./scripts/up.sh` — one command to run the full lab
  - [ ] Step 3: Read the scorecard printed at the end
  - [ ] Step 4: `./scripts/down.sh` — tear down when done
- [ ] Add **Reading the Scorecard** section: explain PASS vs BLOCKED_CRITICAL_FAILURE, what each gate name means, what `Next command` means
- [ ] Add **What just happened?** section: 3-4 sentence narrative — KinD cluster created, app deployed, HPA triggered, proof recorded
- [ ] Keep each section brief (commands-first, prose minimal)

### Task 10.1.2 — Write `docs/concepts.md`: Docker-to-K8s bridge, HPA mental model, NodePort explanation
- [ ] Create `docs/concepts.md`
- [ ] **Docker-to-Kubernetes Bridge** section: if you know Docker, explain that K8s is a scheduler for containers — Pod = running container, Deployment = desired state, Service = stable network endpoint
- [ ] **Two-Layer Mental Model** section: Layer 1 = App (what runs), Layer 2 = Orchestration (how it scales). Draw ASCII diagram: `[Load] → [Service] → [Pod x N] ← [HPA] ← [Metrics Server]`
- [ ] **HPA Explained** section: HPA watches CPU utilization → scales replicas up/down; explain `minReplicas`, `maxReplicas`, `averageUtilization`
- [ ] **NodePort Explained** section: NodePort lets you reach a pod from `localhost:<port>` on a KinD node — explain why this is needed vs ClusterIP
- [ ] **Proof Loop** section: explain what the lab actually measures — baseline replicas, load starts, replicas increase, load stops, replicas decrease

### Task 10.1.3 — Add cross-OS notes (Linux vs macOS differences) to quick-start
- [ ] Add **Platform Notes** section to `docs/quick-start.md`
- [ ] Linux note: Docker Engine directly on host; KinD uses Linux kernel namespaces natively; `free -m` used for memory check
- [ ] macOS note: Docker Desktop required (not just Docker Engine); KinD runs inside the Docker VM; `vm_stat` used for memory check; NodePort accessible via `localhost`
- [ ] WSL2 note: same as Linux path but Docker Desktop for Windows recommended; NodePort accessible via `localhost` from Windows host
- [ ] Note any known macOS-specific `kubectl top nodes` delay (metrics-server may take 60s to first reading)
- [ ] Link to prerequisites for each OS if known-good install instructions exist
