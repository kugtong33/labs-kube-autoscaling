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

| Profile | `maxReplicas` | Min RAM | Use Case |
|---|---|---|---|
| `tiny` | 5 | 2 GB | Laptops, CI pipelines, quick demos |
| `balanced` | 7 | 4 GB | Development workstations |
| `stretch` | 10 | 8 GB | High-spec machines or cloud VMs |

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

Manifests: `k8s/app/landing/` and `k8s/app/api/`.

---

## Load Modes

| Mode | Mechanism | State file | Cleanup |
|---|---|---|---|
| `pod` | `busybox` curl-loop pod in-cluster | none | `kubectl delete pod load-generator -n <ns>` |
| `host` | background `curl` loop on local machine | `.state/load.pid` | `kill $(cat .state/load.pid)` |

Use `./scripts/load.sh --status` to check and `./scripts/load.sh --stop` to stop either mode.

---

## Usage Examples

```bash
# Run with defaults (tiny profile, landing app, pod load)
./scripts/up.sh

# Use balanced profile with API app mode
PROFILE=balanced APP_MODE=api ./scripts/up.sh

# Use host-side load generation (useful when pod networking is restricted)
LOAD_MODE=host ./scripts/up.sh

# Extend the ramp window for a slower machine
HPA_RAMP_SEC=300 ./scripts/up.sh

# Resume after a fix with a specific run ID
./scripts/up.sh --resume hpa_proof --run-id 20260306T120000Z

# Teardown while preserving artifacts
./scripts/down.sh --preserve-artifacts
```
