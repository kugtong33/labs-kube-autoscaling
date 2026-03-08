# Configuration Reference

All configuration is controlled through environment variables. Every variable has a documented default and respects a pre-set value — override any of them without editing scripts:

```bash
PROFILE=balanced APP_MODE=api ./scripts/up.sh
```

---

## Environment Variables

| Variable | Default | Allowed Values | Description |
|---|---|---|---|
| `APP_MODE` | `landing` | `landing` \| `api` | Selects which app image to deploy. `landing` serves an HTML page; `api` serves a single JSON endpoint. |
| `LOAD_MODE` | `pod` | `pod` \| `host` | Controls how load is generated. `pod` runs a busybox curl-loop inside the cluster; `host` runs a curl loop on the local machine. |
| `PROFILE` | `tiny` | `tiny` \| `balanced` \| `stretch` | Controls `maxReplicas` on the HPA and enforces a minimum RAM requirement. See [Profile Ladder](#profile-ladder). |
| `CLUSTER_NAME` | `autoscaling-lab` | any valid KinD name | Name of the KinD cluster created and managed by the lab. |
| `NAMESPACE` | `autoscaling-lab` | any valid K8s name | Kubernetes namespace where all lab resources are created. |
| `APP_DEPLOYMENT` | `sample-app` | any valid deployment name | Name of the Kubernetes Deployment and Service to target. |
| `APP_CONTAINER` | `app` | any valid container name | Name of the container within the deployment used for resource patching (fix HPA-303). |
| `HPA_NAME` | `sample-app-hpa` | any valid HPA name | Name of the HPA resource created by the lab. |
| `HPA_RAMP_SEC` | `180` | positive integer | Seconds the proof gate polls for a scale-up event after load starts. |
| `HPA_COOLDOWN_SEC` | `240` | positive integer | Seconds the proof gate polls for a scale-down event after load stops. |
| `HPA_POLL_SEC` | `10` | positive integer | Polling interval in seconds during ramp and cooldown windows. |
| `ARTIFACT_ROOT` | `artifacts/<run-id>` | any writable path | Root directory for all run artifacts. Set automatically from `RUN_ID`; override for custom paths. |

---

## Profile Ladder

| Profile | `maxReplicas` | Node memory limit | App CPU (req/limit) | App memory limit | Use Case |
|---|---|---|---|---|---|
| `tiny` | 5 | 512 MB | 25m / 200m | 128 Mi | Laptops, CI pipelines, quick demos |
| `balanced` | 7 | 1 GB | 50m / 300m | 256 Mi | Development workstations |
| `stretch` | 10 | 2 GB | 100m / 500m | 512 Mi | High-spec machines or cloud VMs |

**Node memory limit** is applied to the KinD Docker container via `docker update --memory` after cluster creation. This is best-effort — it will be skipped with a warning in environments where Docker memory updates are not supported.

**App resource limits** are hard limits set on the `sample-app` container. Each profile has its own deployment manifest (`k8s/app/<mode>/deployment-<profile>.yaml`).

The profile admission guard runs at the start of `up.sh`:
- **tiny**: always passes (no RAM block).
- **balanced**: warns if available RAM is below 4 GB; does not abort.
- **stretch**: aborts with an error if available RAM is below 8 GB.

---

## App Modes

| Mode | Image | Endpoint | Load Shape |
|---|---|---|---|
| `landing` | `nginx:alpine` | `GET /` → HTML page | High per-request byte cost, good for CPU stress |
| `api` | lightweight HTTP server | `GET /` → `{"status":"ok"}` | Low per-request cost, requires higher concurrency to trigger HPA |

Manifests: `k8s/app/landing/deployment-<profile>.yaml` and `k8s/app/api/deployment-<profile>.yaml` (one file per profile per mode).

---

## Load Modes

| Mode | Mechanism | Default | State file | Cleanup |
|---|---|---|---|---|
| `pod` | `busybox` pod, N parallel `wget` workers per batch (in-cluster) | background (in-cluster) | none | `./scripts/load.sh --stop` |
| `host` | Fibonacci-ramped concurrent `curl` batches on the local machine | **foreground** | `.state/load.pids` (background only) | `./scripts/load.sh --stop` or Ctrl+C |

### Host mode — foreground vs background

`host` mode defaults to foreground: the script runs in the terminal, prints a live progress line, and exits cleanly on Ctrl+C.

```bash
# Foreground (default) — blocks until Ctrl+C
./scripts/load.sh --mode host

# Background — detaches immediately, appends progress to a log file
./scripts/load.sh --mode host --background load.log
tail -f load.log
```

### Fibonacci concurrency ramp (host mode)

Load starts at concurrency 3 and steps up the Fibonacci sequence every 10 seconds:

```
t=0s   concurrency=3
t=10s  concurrency=5
t=20s  concurrency=8
t=30s  concurrency=13
t=40s  concurrency=21
...
```

Each step fires all requests in parallel (background subshells + `wait`) and prints running totals:

```
[load] requests=147    avg_latency= 42ms  concurrency=13
```

Use `./scripts/load.sh --status` to check and `./scripts/load.sh --stop` to stop either mode.

---

## Usage Examples

```bash
# Run with defaults (tiny profile, landing app, pod load)
./scripts/up.sh

# Use balanced profile with API app mode
PROFILE=balanced APP_MODE=api ./scripts/up.sh

# Use host-side load generation (useful when pod networking is restricted)
# Host load runs in background during up.sh (foreground when called directly)
LOAD_MODE=host ./scripts/up.sh

# Extend the ramp window for a slower machine
HPA_RAMP_SEC=300 ./scripts/up.sh

# Resume after a fix with a specific run ID
./scripts/up.sh --resume hpa_proof --run-id 20260306T120000Z

# Teardown while preserving artifacts
./scripts/down.sh --preserve-artifacts
```
