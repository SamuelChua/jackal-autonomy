#!/usr/bin/env bash

set -euo pipefail

IMAGE_REPOSITORY="${JACKAL_AUTONOMY_REPOSITORY:-kumarrobotics/jackal_autonomy}"
IMAGE="${JACKAL_AUTONOMY_IMAGE:-${IMAGE_REPOSITORY}:${JACKAL_AUTONOMY_TAG:-latest}}"

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
container_id="$(docker ps --quiet --filter "ancestor=$IMAGE" | head -n 1)"

if [ -z "$container_id" ]; then
  echo "ERROR: No running container found for image: $IMAGE"
  exit 1
fi

docker exec \
  --privileged \
  -e "DISPLAY=${DISPLAY:-}" \
  -e "LINES=$(tput lines 2>/dev/null || echo 24)" \
  -it \
  "$container_id" \
  bash
