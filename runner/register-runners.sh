#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-jjfishjj}"
RUNNER_ROOT="${RUNNER_ROOT:-/opt/github-runners}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
REPOS=(
  nvidia-full-stack-lab
  cuda-data-residency-lab
  gpu-system-diagnostics-lab
  rdma-nccl-network-lab
  rapids-gpu-pipeline
  dask-multigpu-scaling-lab
)

if [[ "$(uname -s)" != "Linux" ]]; then echo "Linux is required" >&2; exit 2; fi
for command_name in gh curl tar python3 nvidia-smi docker; do command -v "$command_name" >/dev/null || { echo "missing command: $command_name" >&2; exit 2; }; done
gh auth status >/dev/null
python3 "$(dirname "$0")/preflight.py" --container-check --output /tmp/nvidia-runner-preflight.json

if ! id "$RUNNER_USER" >/dev/null 2>&1; then sudo useradd --create-home --shell /bin/bash "$RUNNER_USER"; fi
sudo usermod -aG docker "$RUNNER_USER"
sudo mkdir -p "$RUNNER_ROOT"
sudo chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_ROOT"

runner_tag="$(gh api repos/actions/runner/releases/latest --jq .tag_name)"
runner_version="${runner_tag#v}"
archive="actions-runner-linux-x64-${runner_version}.tar.gz"
download_url="https://github.com/actions/runner/releases/download/${runner_tag}/${archive}"
tmp_archive="/tmp/${archive}"
curl --fail --location --retry 3 "$download_url" --output "$tmp_archive"

for repo in "${REPOS[@]}"; do
  install_dir="$RUNNER_ROOT/$repo"
  if [[ -f "$install_dir/.runner" ]]; then echo "$repo already configured; skipping"; continue; fi
  sudo -u "$RUNNER_USER" mkdir -p "$install_dir"
  sudo -u "$RUNNER_USER" tar -xzf "$tmp_archive" -C "$install_dir"
  sudo "$install_dir/bin/installdependencies.sh"
  token="$(gh api --method POST "repos/$OWNER/$repo/actions/runners/registration-token" --jq .token)"
  labels="gpu,nvidia"
  [[ "$repo" == "rdma-nccl-network-lab" && -d /sys/class/infiniband ]] && labels="$labels,infiniband"
  sudo -u "$RUNNER_USER" bash -c "cd '$install_dir' && ./config.sh --unattended --url 'https://github.com/$OWNER/$repo' --token '$token' --name '$(hostname)-$repo' --labels '$labels' --work '_work'"
  (cd "$install_dir" && sudo ./svc.sh install "$RUNNER_USER" && sudo ./svc.sh start)
done

echo "Runner services installed. Keep GPU workflows workflow_dispatch-only on public repositories."
