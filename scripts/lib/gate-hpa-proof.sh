#!/usr/bin/env bash
# scripts/lib/gate-hpa-proof.sh — HPA proof gate
# Measures baseline, loads the service, observes scale-up, stops load, observes cooldown.
# Source this file; do not execute it directly.

[[ -n "${__GATE_HPA_PROOF_SH:-}" ]] && return
__GATE_HPA_PROOF_SH=1

# ---------------------------------------------------------------------------
# start_load <mode>
# Delegates to ./scripts/load.sh --mode <mode>.
# ---------------------------------------------------------------------------
start_load() {
  local mode="${1:?start_load requires mode}"
  if [[ "${mode}" == "host" ]]; then
    local logfile="${ARTIFACT_ROOT:-artifacts}/load.log"
    ./scripts/load.sh --mode host --preset hpa-proof --background "${logfile}"
  else
    ./scripts/load.sh --mode "${mode}" --preset hpa-proof
  fi
}

# ---------------------------------------------------------------------------
# stop_load
# Delegates to ./scripts/load.sh --stop.
# ---------------------------------------------------------------------------
stop_load() {
  ./scripts/load.sh --stop
}

# ---------------------------------------------------------------------------
# gate_hpa_proof
#
# 1. Precondition checks (301, 302, 303)
# 2. Capture baseline replica count
# 3. Start load; poll replicas for HPA_RAMP_SEC → scale-up required (305)
# 4. Stop load; poll for cooldown up to HPA_COOLDOWN_SEC (306 if no decrease)
#
# Writes replica_samples.csv to ${HPA_DIR}.
# Returns non-zero on any failure.
# ---------------------------------------------------------------------------
gate_hpa_proof() {
  local ns="${NAMESPACE:-autoscaling-lab}"
  local deploy="${APP_DEPLOYMENT:-sample-app}"
  local hpa="${HPA_NAME:-sample-app-hpa}"
  local load_mode="${LOAD_MODE:-pod}"
  local ramp_sec="${HPA_RAMP_SEC:-180}"
  local cool_sec="${HPA_COOLDOWN_SEC:-240}"
  local poll_sec="${HPA_POLL_SEC:-10}"
  local hpa_dir="${HPA_DIR:-artifacts/unset/hpa}"

  mkdir -p "${hpa_dir}"

  # ------------------------------------------------------------------
  # Precondition checks
  # ------------------------------------------------------------------
  echo "[hpa-proof] Checking HPA '${hpa}' in namespace '${ns}'..."
  if ! kubectl -n "${ns}" get hpa "${hpa}" >/dev/null 2>&1; then
    echo "[hpa-proof] FAIL (301): HPA '${hpa}' not found in namespace '${ns}'." >&2
    return 301
  fi
  echo "[hpa-proof] HPA: OK"

  echo "[hpa-proof] Checking metrics availability (kubectl top nodes)..."
  if ! kubectl top nodes >/dev/null 2>/dev/null; then
    echo "[hpa-proof] FAIL (302): kubectl top nodes unavailable — metrics-server not ready." >&2
    return 302
  fi
  echo "[hpa-proof] Node metrics: OK"

  echo "[hpa-proof] Checking pod metrics (kubectl top pods)..."
  if ! kubectl -n "${ns}" top pods >/dev/null 2>/dev/null; then
    echo "[hpa-proof] FAIL (302): kubectl top pods unavailable in namespace '${ns}'." >&2
    return 302
  fi
  echo "[hpa-proof] Pod metrics: OK"

  echo "[hpa-proof] Checking CPU requests on deployment '${deploy}'..."
  local cpu_request
  cpu_request="$(kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.spec.template.spec.containers[*].resources.requests.cpu}' 2>/dev/null || true)"
  if ! echo "${cpu_request}" | grep -q .; then
    echo "[hpa-proof] FAIL (303): No CPU request set on deployment '${deploy}'." >&2
    return 303
  fi
  echo "[hpa-proof] CPU request: ${cpu_request} — OK"

  # ------------------------------------------------------------------
  # Baseline capture
  # ------------------------------------------------------------------
  local baseline
  baseline="$(kubectl -n "${ns}" get deploy "${deploy}" \
    -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
  baseline="${baseline:-1}"
  local max_seen="${baseline}"

  echo "[hpa-proof] Baseline replicas: ${baseline}"

  local csv="${hpa_dir}/replica_samples.csv"
  echo "ts,replicas" > "${csv}"

  # ------------------------------------------------------------------
  # Pre-load artifact snapshots
  # ------------------------------------------------------------------
  echo "[hpa-proof] Capturing pre-load HPA artifacts..."
  kubectl -n "${ns}" describe hpa "${hpa}" > "${hpa_dir}/hpa_describe.txt" 2>&1 || true
  kubectl -n "${ns}" get hpa "${hpa}" -o yaml > "${hpa_dir}/hpa.yaml" 2>&1 || true
  kubectl top nodes > "${hpa_dir}/top_nodes.txt" 2>&1 || true
  kubectl -n "${ns}" top pods > "${hpa_dir}/top_pods.txt" 2>&1 || true
  echo "[hpa-proof] Artifacts: hpa_describe.txt, hpa.yaml, top_nodes.txt, top_pods.txt"

  # ------------------------------------------------------------------
  # Start load
  # ------------------------------------------------------------------
  echo "[hpa-proof] Starting load (mode=${load_mode})..."
  if ! start_load "${load_mode}"; then
    echo "[hpa-proof] FAIL (304): start_load failed." >&2
    return 304
  fi
  echo "[hpa-proof] Load started."

  # ------------------------------------------------------------------
  # Scale-up polling loop
  # ------------------------------------------------------------------
  echo "[hpa-proof] Polling replicas for ${ramp_sec}s (poll interval: ${poll_sec}s)..."
  local elapsed=0
  local current

  while [[ "${elapsed}" -lt "${ramp_sec}" ]]; do
    current="$(kubectl -n "${ns}" get deploy "${deploy}" \
      -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
    current="${current:-${baseline}}"

    echo "$(date -u +%FT%TZ),${current}" >> "${csv}"
    echo "[hpa-proof] t=${elapsed}s replicas=${current} (max=${max_seen})"

    if [[ "${current}" -gt "${max_seen}" ]]; then
      max_seen="${current}"
    fi

    elapsed=$(( elapsed + poll_sec ))
    [[ "${elapsed}" -lt "${ramp_sec}" ]] && sleep "${poll_sec}"
  done

  if [[ "${max_seen}" -le "${baseline}" ]]; then
    echo "[hpa-proof] FAIL (305): No scale-up observed. max_seen=${max_seen}, baseline=${baseline}." >&2
    stop_load || true
    return 305
  fi

  echo "[hpa-proof] Scale-up confirmed: max_seen=${max_seen} > baseline=${baseline}"

  # ------------------------------------------------------------------
  # Cooldown polling loop
  # ------------------------------------------------------------------
  echo "[hpa-proof] Stopping load..."
  stop_load || true

  echo "[hpa-proof] Polling for cooldown up to ${cool_sec}s..."
  elapsed=0
  local cooled=0

  while [[ "${elapsed}" -lt "${cool_sec}" ]]; do
    current="$(kubectl -n "${ns}" get deploy "${deploy}" \
      -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
    current="${current:-${max_seen}}"

    echo "$(date -u +%FT%TZ),${current}" >> "${csv}"
    echo "[hpa-proof] t=${elapsed}s replicas=${current} (peak=${max_seen})"

    if [[ "${current}" -lt "${max_seen}" ]]; then
      cooled=1
      break
    fi

    elapsed=$(( elapsed + poll_sec ))
    [[ "${elapsed}" -lt "${cool_sec}" ]] && sleep "${poll_sec}"
  done

  if [[ "${cooled}" -ne 1 ]]; then
    echo "[hpa-proof] FAIL (306): No cooldown observed within ${cool_sec}s." >&2
    {
      echo "HPA scale-up proved (baseline=${baseline}, max_seen=${max_seen})"
      echo "Cooldown not observed within ${cool_sec}s"
    } > "${hpa_dir}/summary.txt"
    return 306
  fi

  echo "[hpa-proof] Cooldown confirmed: replicas decreased from peak ${max_seen} to ${current}"

  # ------------------------------------------------------------------
  # PASS summary
  # ------------------------------------------------------------------
  {
    echo "PASS"
    echo "baseline_replicas=${baseline}"
    echo "max_replicas_seen=${max_seen}"
    echo "scale_up_window_sec=${ramp_sec}"
    echo "cooldown_window_sec=${cool_sec}"
    echo "samples_file=${csv}"
  } > "${hpa_dir}/summary.txt"

  echo "[hpa-proof] HPA proof complete. Artifacts: ${hpa_dir}/"
  return 0
}
