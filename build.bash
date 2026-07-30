#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BASE_IMAGE="${BASE_IMAGE:-kumarrobotics/dcist-master-jazzy-nvda:latest}"
IMAGE="${JACKAL_AUTONOMY_IMAGE:-kumarrobotics/jackal_autonomy:jazzy-20260730-r4}"

if [ "$(id -u)" -ne 1000 ]; then
  echo "ERROR: This script must be run by the UID-1000 host user."
  echo "       Current UID: $(id -u), current GID: $(id -g)"
  exit 1
fi

if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Required base image is not available locally: $BASE_IMAGE"
  echo "This script will not rebuild or substitute for the base image."
  exit 2
fi

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Refusing to overwrite existing image: $IMAGE"
  echo "Set JACKAL_AUTONOMY_IMAGE to a new, unused tag before building."
  exit 3
fi

echo -e "\033[0;35mBUILDING JACKAL AUTONOMY IMAGE\033[0m"
echo -e "\033[0;35mBASE IMAGE: \033[0m$BASE_IMAGE"
echo -e "\033[0;35mOUTPUT IMAGE: \033[0m$IMAGE"

docker build \
  --build-arg "BASE_IMAGE=$BASE_IMAGE" \
  --file "$PROJECT_DIR/Dockerfile" \
  --tag "$IMAGE" \
  "$PROJECT_DIR"

echo -e "\033[0;35mBUILT: \033[0m$IMAGE"
