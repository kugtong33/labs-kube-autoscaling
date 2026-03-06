# Local Kubernetes Autoscaling Lab

A reproducible, self-contained lab that provisions a KinD cluster, proves Horizontal Pod Autoscaler (HPA) scale-up and cooldown behavior under synthetic load, and collects evidence artifacts — all from a single command.

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| `docker` | 20+ | Container runtime; required by KinD |
| `kind` | 0.20+ | Local Kubernetes cluster |
| `kubectl` | 1.28+ | Cluster interaction |
| `node` | 18+ | Outcome resolver and scorecard |
| `bash` | 3.2+ | All orchestration scripts |
| `curl` | any | Reachability smoke checks |

---

## Quick Start

```bash
# 1. Bring up the lab (provisions cluster, proves HPA, collects evidence)
./scripts/up.sh

# 2. Observe the scorecard and follow the printed next_command

# 3. Tear down
./scripts/down.sh
```

---

## Configuration

All behaviour is controlled via environment variables. Defaults work out of the box.

| Variable | Default | Options |
|---|---|---|
| `APP_MODE` | `landing` | `landing`, `api` |
| `LOAD_MODE` | `pod` | `pod`, `host` |
| `PROFILE` | `tiny` | `tiny`, `balanced`, `stretch` |

Example — run with API mode and balanced profile:

```bash
APP_MODE=api PROFILE=balanced ./scripts/up.sh
```

See `docs/configuration.md` for the full reference.

---

## Project Layout

```
.
├── scripts/
│   ├── up.sh               # Main entrypoint: provision → prove → evidence
│   ├── down.sh             # Teardown
│   ├── load.sh             # Load generator (pod or host mode)
│   ├── fix.sh              # HPA failure code dispatcher
│   ├── collect-evidence.sh # Standalone evidence re-run
│   └── lib/                # Shared library functions
│       ├── config.sh           # Env var defaults and profile logic
│       ├── gate-runner.sh      # run_gate orchestration wrapper
│       ├── run-context.sh      # RUN_ID, artifact paths
│       ├── gate-bootstrap.sh   # Bootstrap + integrity gates
│       ├── gate-reachability.sh
│       ├── gate-hpa-proof.sh
│       ├── gate-evidence.sh
│       ├── gate-teardown.sh
│       ├── failure-maps.sh     # print_failure_hint, print_next_command_for_code
│       ├── scorecard.sh        # print_final_scorecard
│       └── outcome-resolver.js # Node-based outcome resolver
├── k8s/
│   ├── app/
│   │   ├── landing/        # Landing-page deployment + service
│   │   └── api/            # API deployment + service
│   ├── addons/
│   │   └── metrics-server.yaml
│   ├── presets/
│   │   ├── hpa-proof.yaml           # Demo-safe HPA preset
│   │   └── deployment-tiny-safe.yaml
│   ├── hpa-tiny.yaml
│   ├── hpa-balanced.yaml
│   └── hpa-stretch.yaml
├── docs/
│   ├── quick-start.md
│   ├── configuration.md
│   ├── troubleshooting.md
│   ├── concepts.md
│   └── artifact-reference.md
├── artifacts/              # Per-run output (gitignored)
│   └── <run-id>/
│       ├── scorecard.jsonl
│       ├── final_scorecard.json
│       ├── gates/
│       └── hpa/
└── .state/                 # Runtime state (gitignored)
    └── last_run_id
```

---

## Gate Pipeline

```
Bootstrap → Reachability → HPA Proof → Evidence Capture → Teardown Integrity
  (CRITICAL)   (CRITICAL)   (CRITICAL)   (NON_CRITICAL)    (NON_CRITICAL)
```

Each gate is severity-aware: CRITICAL failures exit immediately with a mapped fix command; NON_CRITICAL failures warn and continue.

---

## Recovery

If a gate fails, the scorecard prints a deterministic `next_command`:

```bash
# Example: HPA proof failed with code 302 (metrics unavailable)
./scripts/fix.sh HPA-302

# After the fix, resume from where you left off
./scripts/up.sh --resume hpa_proof
```

Each failure code (HPA-301 through HPA-306) has a 3-attempt escalation ladder. See `docs/troubleshooting.md`.

---

## Profiles

| Profile | `maxReplicas` | Min RAM |
|---|---|---|
| `tiny` | 5 | 2 GB |
| `balanced` | 7 | 4 GB |
| `stretch` | 10 | 8 GB |
