#!/usr/bin/env bash
set -Eeuo pipefail
exec > >(tee -a /var/log/github-gpu-runner.log) 2>&1

metadata() {
  curl --fail --silent --show-error -H 'Metadata-Flavor: Google' \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1"
}

repo="$(metadata github-repository)"
secret_id="$(metadata runner-secret)"
unique_label="$(metadata runner-label)"
profile_labels="$(metadata runner-profile-labels)"
ttl_minutes="$(metadata runner-ttl-minutes)"
project_id="$(curl --fail --silent -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/project/project-id)"

# Independent backstop: even if GitHub cleanup is interrupted, the costly VM stops.
shutdown -h "+${ttl_minutes}"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl jq ca-certificates docker.io
systemctl enable --now docker
if command -v nvidia-ctk >/dev/null 2>&1; then
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
fi
nvidia-smi -L

id -u actions >/dev/null 2>&1 || useradd --create-home --shell /bin/bash actions
usermod -aG docker actions
install -d -o actions -g actions /opt/actions-runner

runner_version="$(curl --fail --silent --show-error https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name | ltrimstr("v")')"
[[ "$runner_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "could not resolve GitHub runner version" >&2; exit 1; }
curl --fail --location --retry 5 --output /tmp/actions-runner.tgz \
  "https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-linux-x64-${runner_version}.tar.gz"
tar -xzf /tmp/actions-runner.tgz -C /opt/actions-runner
chown -R actions:actions /opt/actions-runner

runner_token="$(gcloud secrets versions access latest --secret "$secret_id" --project "$project_id")"
[[ -n "$runner_token" ]] || { echo "empty runner token" >&2; exit 1; }

su -s /bin/bash actions -c "cd /opt/actions-runner && ./config.sh \
  --url 'https://github.com/${repo}' \
  --token '${runner_token}' \
  --name '$(hostname)' \
  --labels 'gpu,nvidia,gcp,${profile_labels},${unique_label}' \
  --work '_work' \
  --ephemeral --unattended --disableupdate"
unset runner_token

cd /opt/actions-runner
exec runuser -u actions -- ./run.sh
