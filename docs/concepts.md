# Concepts

Core ideas behind the autoscaling lab — written for someone who knows Docker but is new to Kubernetes.

---

## Docker-to-Kubernetes Bridge

If you know Docker, here is the mapping:

| Docker concept | Kubernetes equivalent | What it does |
|---------------|----------------------|--------------|
| `docker run` | **Pod** | A running container (or group of containers) |
| `docker-compose service` | **Deployment** | Declares desired state — "run N copies of this image" |
| Port mapping (`-p 8080:80`) | **Service** | Stable network endpoint; routes traffic to pods |
| — | **HPA** | Watches metrics and adjusts replica count automatically |

Kubernetes is a scheduler: you describe what you want, and it makes it happen — including reacting to load.

---

## Two-Layer Mental Model

```
Layer 1 — App (what runs)
─────────────────────────────────────────────────
  [Deployment: sample-app]  →  [Pod] [Pod] [Pod]
                                       ↑
  [Service: NodePort 30080] ──────────┘

Layer 2 — Orchestration (how it scales)
─────────────────────────────────────────────────
  [Load Generator]
       │  HTTP requests
       ▼
  [Service] → [Pod x N] ← [HPA] ← [Metrics Server]
                               watches CPU utilization
                               adjusts replica count
```

- **Layer 1** is what you deploy: an app and a service to reach it.
- **Layer 2** is what makes it interesting: the HPA watches CPU and automatically adjusts how many pods are running.

---

## HPA Explained

The **HorizontalPodAutoscaler** watches a metric (CPU utilization in this lab) and scales the number of pod replicas to keep that metric near a target.

Key fields in the HPA manifest:

```yaml
spec:
  minReplicas: 1        # never scale below this
  maxReplicas: 5        # never scale above this
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50  # target: keep average CPU at 50%
```

**Scale-up:** If average CPU across all pods exceeds 50%, the HPA adds replicas to spread the load.

**Scale-down:** After load stops, CPU drops. The HPA waits for a stabilization window (default: 5 minutes) before removing replicas.

The lab uses a short observation window and preset manifests to demonstrate both directions within a single run.

---

## NodePort Explained

By default, pods are only reachable inside the cluster (**ClusterIP**). To reach an app from your laptop, you need a **NodePort** service.

```
Your browser / curl
      │  localhost:30080
      ▼
[KinD Node (Docker container)]
      │  port forwarded to pod
      ▼
[Pod: sample-app :80]
```

NodePort assigns a port in the range `30000–32767` on the cluster node. Because KinD runs as a Docker container, that port is accessible on `localhost`. This is why the lab hardcodes NodePort `30080` — it is the fixed address the reachability gate checks.

ClusterIP would only work from inside the cluster. NodePort is the simplest way to expose a service for local development and demos.

---

## Proof Loop

The lab proves autoscaling by measuring four things in sequence:

1. **Baseline** — Record how many replicas are running before load starts (usually 1).
2. **Scale-up** — Start the load generator. Poll replicas every `HPA_POLL_SEC` seconds for up to `HPA_RAMP_SEC` seconds. Record the peak (`max_seen`). If `max_seen > baseline`, scale-up is proven.
3. **Scale-down** — Stop the load generator. Poll replicas for up to `HPA_COOLDOWN_SEC` seconds. If replicas drop below peak, cooldown is proven.
4. **Artifacts** — Every replica count reading is written to `replica_samples.csv` with a timestamp. The `summary.txt` records the final verdict.

A successful proof means the HPA both scaled **up** under load and scaled **down** after load — demonstrating the full autoscaling lifecycle.
