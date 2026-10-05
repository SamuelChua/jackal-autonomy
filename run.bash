#!/usr/bin/env bash

set -euo pipefail


PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
IMAGE_REPOSITORY="${JACKAL_AUTONOMY_REPOSITORY:-kumarrobotics/jackal_autonomy}"
IMAGE="${JACKAL_AUTONOMY_IMAGE:-${IMAGE_REPOSITORY}:${JACKAL_AUTONOMY_TAG:-bridge-spine-v1}}"
USER_WS="$PROJECT_DIR/ws"
DATA_DIR="$PROJECT_DIR/data"
ROS_DIR="$PROJECT_DIR/.ros_docker"
BASHRC_HOST="$PROJECT_DIR/bashrc"
ZED_CONFIG="$DATA_DIR/configs/zed2i.yaml"
ZED_SETTINGS="${JACKAL_AUTONOMY_ZED_SETTINGS:-$DATA_DIR/configs/usr/local/zed/settings}"

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

if [ ! -d "$USER_WS/src/jackal_nav2" ] || [ ! -d "$USER_WS/src/jackal_serial" ]; then
  echo "ERROR: Workspace is missing or incomplete: $USER_WS"
  echo "Run ./sync_workspace.bash before starting the container."
  exit 2
fi

if [ ! -d "$ZED_SETTINGS" ]; then
  echo "ERROR: ZED settings directory is missing: $ZED_SETTINGS"
  exit 2
fi

if ! "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Image is not available locally: $IMAGE"
  echo "Build it with ./build.bash."
  exit 3
fi

jackal_check_image_uid "$IMAGE"
for required in "$BASHRC_HOST" "$ZED_CONFIG"; do
  [ -f "$required" ] || { echo "Missing runtime file: $required"; exit 2; }
done
mkdir -p "$ROS_DIR" "$DATA_DIR/weights" "$DATA_DIR/vlm-inspections"

XAUTH_FILE="/tmp/.jackal_autonomy.$(id -u).docker.xauth"
touch "$XAUTH_FILE"
if command -v xauth >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  xauth_list="$(xauth nlist "${DISPLAY}" 2>/dev/null | sed -e 's/^..../ffff/' || true)"
  if [ -n "$xauth_list" ]; then
    echo "$xauth_list" | xauth -f "$XAUTH_FILE" nmerge -
  fi
fi
chmod a+r "$XAUTH_FILE"

echo -e "\033[1;35mRUNNING DOCKER IMAGE: \033[0m$IMAGE"
echo -e "\033[1;35mUSER WORKSPACE: \033[0m$USER_WS"
echo -e "\033[1;35mDATA DIR: \033[0m$DATA_DIR"
echo -e "\033[1;35mROS DIR: \033[0m$ROS_DIR"
echo -e "\033[1;35mBASHRC HOST: \033[0m$BASHRC_HOST"

docker_args=(
  run
  --gpus "${JACKAL_AUTONOMY_GPUS:-all}"
  --user dcist
  --mount "type=bind,src=$ZED_SETTINGS,dst=/usr/local/zed/settings,readonly"
  -it
  --workdir /home/dcist
  --privileged
  -e "DISPLAY=${DISPLAY:-}"
  -e QT_X11_NO_MITSHM=1
  -e "XAUTHORITY=$XAUTH_FILE"
  --mount "type=bind,src=$USER_WS,dst=/home/dcist/dcist_ws"
  --mount "type=bind,src=$DATA_DIR,dst=/home/dcist/data"
  --mount "type=bind,src=$ROS_DIR,dst=/home/dcist/.ros"
  --mount "type=bind,src=$BASHRC_HOST,dst=/home/dcist/.bashrc_host,readonly"
  --mount "type=bind,src=$ZED_CONFIG,dst=/home/dcist/dcist_ws/src/zed-ros2-wrapper/zed_wrapper/config/zed2i.yaml,readonly"
  --mount "type=bind,src=$XAUTH_FILE,dst=$XAUTH_FILE,readonly"
  --volume /tmp/.X11-unix:/tmp/.X11-unix
  --volume /etc/localtime:/etc/localtime:ro
  --volume /dev:/dev
  --network host
  --hostname dcist
  --add-host dcist:127.0.0.1
  --add-host "dcist:${DCIST_HOST_IP:-192.168.8.100}"
  --security-opt seccomp=unconfined
  --group-add dialout
  --rm
)

if input_gid="$(getent group input | cut -d: -f3)" && [ -n "$input_gid" ]; then
  docker_args+=(--group-add "$input_gid")
fi
if video_gid="$(getent group video | cut -d: -f3)" && [ -n "$video_gid" ]; then
  docker_args+=(--group-add "$video_gid")
fi

if [ -f "${HOME}/.bash_history" ]; then
  docker_args+=(--mount "type=bind,src=${HOME}/.bash_history,dst=/home/dcist/.bash_history")
fi
if [ -d "/media/${USER}" ]; then
  docker_args+=(--mount "type=bind,src=/media/${USER},dst=/media/dcist")
fi
if [ -n "${CLEARPATH_DIR:-}" ] && [ -d "$CLEARPATH_DIR" ]; then
  docker_args+=(--mount "type=bind,src=$CLEARPATH_DIR,dst=/etc/clearpath,readonly")
fi

# Explicit shell: this helper never starts a sensor, controller, or mission.
docker_args+=(--entrypoint /bin/bash "$IMAGE")
"${DOCKER[@]}" "${docker_args[@]}"
