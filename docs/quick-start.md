# Quick Start

Get to a successful HPA proof in under 15 minutes.

---

## Prerequisites

| Tool | Min Version | Install |
|------|-------------|---------|
| `docker` | 20.10+ | https://docs.docker.com/get-docker/ |
| `kind` | 0.20+ | https://kind.sigs.k8s.io/docs/user/quick-start/#installation |
| `kubectl` | 1.27+ | https://kubernetes.io/docs/tasks/tools/ |
| `node` | 18+ | https://nodejs.org/ |
| `bash` | 4.0+ | Pre-installed on Linux/macOS (macOS ships 3.x — install via Homebrew: `brew install bash`) |
| `curl` | any | Pre-installed on most systems |

---

## Quick Start

**Step 1 — Clone the repo** (skip if already done)

```bash
git clone <repo-url>
cd labs-kube-autoscaling
```

**Step 2 — Run the full lab**

```bash
./scripts/up.sh
```

This single command provisions a KinD cluster, deploys the app and HPA, generates load, observes autoscaling, and records proof artifacts.

Optional flags:

```bash
./scripts/up.sh --profile balanced   # more replicas (needs ≥4GB RAM)
./scripts/up.sh --app-mode api       # JSON endpoint instead of HTML page
./scripts/up.sh --load-mode host     # run load from host (fibonacci ramp, background during proof)
```

If KinD cluster creation fails (e.g. a port conflict), `up.sh` automatically cleans up the failed node and retries once before aborting.

**Step 3 — Read the scorecard**

At the end of `up.sh`, a scorecard is printed. See [Reading the Scorecard](#reading-the-scorecard) below.

**Step 4 — Tear down**

```bash
./scripts/down.sh                # deletes namespace and KinD cluster
./scripts/down.sh --keep-cluster # deletes namespace but keeps the KinD cluster
```

---

## Reading the Scorecard

```
=== Autoscaling Lab Scorecard ===
RUN_ID:   20240315-142301
MODE:     full_run

Critical gates:     4/4 passed
Non-critical gates: 1/1 passed

Overall status: LEARNING_COMPLETE
Next command:   ./scripts/down.sh
=================================
```

**Overall status values:**

| Status | Meaning |
|--------|---------|
| `LEARNING_COMPLETE` | All critical gates passed — proof recorded |
| `BLOCKED_CRITICAL_FAILURE` | A gate failed — follow `Next command` to fix |
| `LEARNING_READY_WITH_WARNINGS` | Passed with non-critical warnings |

**Gate names:**

| Gate | What it checks |
|------|----------------|
| `bootstrap_gate` | KinD cluster + namespace + metrics-server + app deployed |
| `reachability_gate` | App responds on NodePort via HTTP |
| `hpa_proof` | Load triggers scale-up; cooldown brings replicas back down |
| `evidence_capture` | Artifacts collected (non-critical) |

**Next command:** The exact command to run next — either `down.sh` on success or `fix.sh HPA-30X` on failure.

---

## What just happened?

A KinD (Kubernetes-in-Docker) cluster was created on your machine. The sample app was deployed as a Kubernetes Deployment with an HPA configured to scale when CPU exceeds 50%. A load generator drove CPU above the threshold, causing the HPA to add replicas — proving autoscaling works. When load stopped, replicas scaled back down. All timings and replica counts were captured as artifacts in `artifacts/<RUN_ID>/`.

---

## Platform Notes

### Linux

- Docker Engine runs directly on the host; KinD uses Linux kernel namespaces natively.
- Available memory is detected with `free -m`.
- No extra configuration needed.

### macOS

- **Docker Desktop** is required (not just Docker Engine) — KinD runs inside the Docker Desktop VM.
- Available memory is detected with `vm_stat`.
- NodePort is accessible via `localhost` on the same port.
- **Known delay:** `kubectl top nodes` may take up to 60 seconds to return its first reading after metrics-server starts. The bootstrap gate retries automatically.
- Homebrew install: `brew install kind kubectl node` and `brew install bash` (for bash 4+).

### WSL2 (Windows)

- Follow the Linux path inside your WSL2 distribution.
- **Docker Desktop for Windows** is recommended — enable the WSL2 backend in Docker Desktop settings.
- NodePort is accessible via `localhost` from both the WSL2 shell and the Windows host browser.
- Memory detection uses the Linux `free -m` path inside WSL2.
