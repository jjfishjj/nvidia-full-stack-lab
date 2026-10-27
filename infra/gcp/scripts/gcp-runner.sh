#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "usage: $0 create|delete l4|h100 INSTANCE SECRET UNIQUE_LABEL [--spot]" >&2
  exit 64
}

[[ $# -ge 5 ]] || usage
action="$1"; profile="$2"; instance="$3"; secret_id="$4"; unique_label="$5"
spot="${6:-}"

for value in "$instance" "$secret_id" "$unique_label"; do
  [[ "$value" =~ ^[a-z][a-z0-9-]{2,62}$ ]] || { echo "unsafe resource name: $value" >&2; exit 64; }
done
[[ "$action" == "create" || "$action" == "delete" ]] || usage
[[ "$profile" == "l4" || "$profile" == "h100" ]] || usage
[[ -n "${GCP_PROJECT_ID:-}" ]] || { echo "GCP_PROJECT_ID is required" >&2; exit 64; }
[[ -n "${GCP_RUNNER_SERVICE_ACCOUNT:-}" ]] || { echo "GCP_RUNNER_SERVICE_ACCOUNT is required" >&2; exit 64; }

if [[ "$profile" == "l4" ]]; then
  zone="asia-east1-a"
  machine_type="g2-standard-4"
  accelerator=(--accelerator="type=nvidia-l4,count=1")
  profile_labels="l4"
else
  zone="asia-east1-c"
  machine_type="a3-highgpu-8g"
  accelerator=()
  profile_labels="h100,nvlink,multigpu"
fi

delete_resources() {
  gcloud compute instances delete "$instance" --project "$GCP_PROJECT_ID" --zone "$zone" --quiet || true
  gcloud secrets delete "$secret_id" --project "$GCP_PROJECT_ID" --quiet || true
}

if [[ "$action" == "delete" ]]; then
  delete_resources
  exit 0
fi

[[ -f "${RUNNER_TOKEN_FILE:-}" ]] || { echo "RUNNER_TOKEN_FILE is required for create" >&2; exit 64; }
[[ "$spot" == "" || "$spot" == "--spot" ]] || usage

image_family="${GCP_IMAGE_FAMILY:-common-cu128-ubuntu-2204-nvidia-570}"
image_project="${GCP_IMAGE_PROJECT:-deeplearning-platform-release}"
startup_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/startup/gpu-runner.sh"

trap 'echo "provisioning failed; removing partial resources" >&2; delete_resources' ERR

gcloud secrets create "$secret_id" --project "$GCP_PROJECT_ID" --replication-policy=automatic --quiet
gcloud secrets versions add "$secret_id" --project "$GCP_PROJECT_ID" --data-file="$RUNNER_TOKEN_FILE" --quiet
gcloud secrets add-iam-policy-binding "$secret_id" --project "$GCP_PROJECT_ID" \
  --member="serviceAccount:${GCP_RUNNER_SERVICE_ACCOUNT}" --role=roles/secretmanager.secretAccessor --quiet

provisioning=()
if [[ "$spot" == "--spot" ]]; then
  provisioning=(--provisioning-model=SPOT)
fi

gcloud compute instances create "$instance" \
  --project "$GCP_PROJECT_ID" \
  --zone "$zone" \
  --machine-type "$machine_type" \
  "${accelerator[@]}" \
  --image-family "$image_family" \
  --image-project "$image_project" \
  --boot-disk-size=200GB \
  --boot-disk-type=pd-balanced \
  --maintenance-policy=TERMINATE \
  --network=github-gpu \
  --subnet=github-gpu-taiwan \
  --service-account="$GCP_RUNNER_SERVICE_ACCOUNT" \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --no-address \
  --max-run-duration=2h \
  --instance-termination-action=DELETE \
  --metadata-from-file=startup-script="$startup_script" \
  --metadata="github-repository=${GITHUB_REPOSITORY},runner-secret=${secret_id},runner-label=${unique_label},runner-profile-labels=${profile_labels},runner-ttl-minutes=120" \
  --labels="managed-by=github-actions,runner-profile=${profile},github-run-id=${GITHUB_RUN_ID}" \
  "${provisioning[@]}" \
  --quiet

trap - ERR
echo "Created $instance ($profile) in $zone; it has no public IP and will accept one job."
