#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
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
jackal_check_image_uid "$IMAGE"
container_id="$("${DOCKER[@]}" ps --quiet --filter "ancestor=$IMAGE" | head -n 1)"

if [ -z "$container_id" ]; then
  echo "ERROR: No running container found for image: $IMAGE"
  exit 1
fi

"${DOCKER[@]}" exec \
  --user dcist \
  --privileged \
  -e "DISPLAY=${DISPLAY:-}" \
  -e "LINES=$(tput lines 2>/dev/null || echo 24)" \
  -it \
  "$container_id" \
  bash
