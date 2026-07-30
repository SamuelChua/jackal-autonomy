#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:-${JACKAL_AUTONOMY_IMAGE:-kumarrobotics/jackal_autonomy:jazzy-20260730-r4}}"
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
