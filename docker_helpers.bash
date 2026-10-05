#!/usr/bin/env bash
# Source from the host helpers. Keep host-side mounts and files owned by the user.
jackal_docker_init() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "Run this helper as your regular user. For Docker access use:"
    echo "  JACKAL_DOCKER_SUDO=1 ./$(basename "$0") [options]"
    return 1
  fi
  DOCKER=(docker)
  case "${JACKAL_DOCKER_SUDO:-0}" in
    0) ;;
    1) DOCKER=(sudo docker) ;;
    *) echo "JACKAL_DOCKER_SUDO must be 0 or 1"; return 1 ;;
  esac
  if ! "${DOCKER[@]}" info >/dev/null; then
    echo "Cannot access Docker. Check the daemon or use JACKAL_DOCKER_SUDO=1."
    return 1
  fi
}
jackal_check_image_uid() {
  local image_uid
  image_uid="$("${DOCKER[@]}" image inspect --format '{{index .Config.Labels "org.kumarrobotics.jackal.host-uid"}}' "$1")"
  if [ "$image_uid" != "$(id -u)" ]; then
    echo "Image UID label ($image_uid) does not match host UID $(id -u)."
    echo "Build the research image with HOST_UID matching its base dcist user and this host."
    return 1
  fi
}
