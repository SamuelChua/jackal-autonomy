#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BASE_IMAGE="${BASE_IMAGE:-dcist-master-jazzy-nvda:bridge-base-b20fac7}"
IMAGE_REPOSITORY="${JACKAL_AUTONOMY_REPOSITORY:-kumarrobotics/jackal_autonomy}"
IMAGE="${JACKAL_AUTONOMY_IMAGE:-${IMAGE_REPOSITORY}:${JACKAL_AUTONOMY_TAG:-bridge-spine-v1}}"

usage() {
  echo "Usage: $0 [-t|--tag TAG]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -t|--tag)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: $1 requires a tag."
        usage
        exit 2
      fi
      IMAGE="${IMAGE_REPOSITORY}:$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

source "$PROJECT_DIR/docker_helpers.bash"
jackal_docker_init

if ! "${DOCKER[@]}" image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Required base image is not available locally: $BASE_IMAGE"
  echo "This script will not rebuild or substitute for the base image."
  exit 2
fi


if "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Output image already exists: $IMAGE. Choose a new --tag."
  exit 3
fi

echo -e "\033[0;35mBUILDING JACKAL AUTONOMY IMAGE\033[0m"
echo -e "\033[0;35mBASE IMAGE: \033[0m$BASE_IMAGE"
echo -e "\033[0;35mOUTPUT IMAGE: \033[0m$IMAGE"

"${DOCKER[@]}" build \
  --build-arg "BASE_IMAGE=$BASE_IMAGE" \
  --build-arg "HOST_UID=$(id -u)" \
  --file "$PROJECT_DIR/Dockerfile" \
  --tag "$IMAGE" \
  "$PROJECT_DIR"

echo -e "\033[0;35mBUILT: \033[0m$IMAGE"
