#!/usr/bin/env bash
set -uo pipefail

root="${1:-projects}"
results="${2:-baseline-results}"
mkdir -p "$results"
failures=0

record_failure() { echo "$1" >> "$results/failures.txt"; failures=$((failures + 1)); }

python3 runner/preflight.py --container-check --output "$results/preflight.json" || record_failure preflight
nvidia-smi -q > "$results/nvidia-smi-q.txt" 2>&1 || record_failure nvidia-smi
nvidia-smi topo -m > "$results/topology.txt" 2>&1 || record_failure topology

docker build -t nvidia-lab/cuda "$root/cuda-data-residency-lab" && \
  docker run --rm --gpus all nvidia-lab/cuda 16777216 20 > "$results/cuda.json" || record_failure cuda

nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit,clocks_throttle_reasons.active --format=csv,noheader,nounits > "$results/nvidia-smi.csv" && \
  docker build -t nvidia-lab/diagnostics "$root/gpu-system-diagnostics-lab" && \
  docker run --rm --gpus all -v "$PWD/$results:/results:ro" nvidia-lab/diagnostics --input /results/nvidia-smi.csv > "$results/diagnostics.json" || record_failure diagnostics

docker build -t nvidia-lab/pod "$root/pod-architecture-planner" && \
  docker run --rm nvidia-lab/pod --gpus "${POD_GPU_COUNT:-256}" > "$results/pod.json" || record_failure pod

docker build -t nvidia-lab/rapids "$root/rapids-gpu-pipeline" && \
  docker run --rm --gpus all --ipc=host nvidia-lab/rapids --rows "${RAPIDS_ROWS:-10000000}" --backend gpu > "$results/rapids.json" || record_failure rapids

docker build -t nvidia-lab/dask "$root/dask-multigpu-scaling-lab" && \
  docker run --rm --gpus all --ipc=host --ulimit memlock=-1:-1 nvidia-lab/dask --elements "${DASK_ELEMENTS:-100000000}" > "$results/dask.json" || record_failure dask

if [[ -d /dev/infiniband ]]; then
  docker build -t nvidia-lab/nccl "$root/rdma-nccl-network-lab" && \
    docker run --rm --gpus all --network host --ipc=host --ulimit memlock=-1:-1 --cap-add IPC_LOCK \
      -v /dev/infiniband:/dev/infiniband -v "$PWD/$results:/results" \
      -e NCCL_TESTS_HOME=/opt/nccl-tests -e THEORETICAL_GBPS="${THEORETICAL_GBPS:-200}" \
      nvidia-lab/nccl bash scripts/run_nccl_benchmark.sh /results/network-report && \
    cp "$results/network-report/summary.json" "$results/rdma-summary.json" || record_failure rdma
else
  printf '{"status":"skipped","reason":"no /dev/infiniband"}\n' > "$results/rdma-summary.json"
fi

python3 runner/render_report.py "$results" --output "$results/report.md"
echo "baseline completed with $failures failure(s)"
exit "$failures"
