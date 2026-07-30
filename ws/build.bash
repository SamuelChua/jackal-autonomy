#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
PARALLEL_WORKERS="${COLCON_PARALLEL_WORKERS:-4}"
RUN_ROSDEP=1

if [ "${1:-}" = "--skip-rosdep" ]; then
  RUN_ROSDEP=0
elif [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--skip-rosdep]"
  exit 2
fi

set +u
source "/opt/ros/${ROS_DISTRO}/setup.bash"
set -u

if [ "$RUN_ROSDEP" -eq 1 ]; then
  rosdep install \
    --from-paths "$WORKSPACE_DIR/src" \
    --ignore-src \
    --rosdistro "$ROS_DISTRO" \
    --skip-keys "ament_python ament_pytest" \
    -r \
    -y
fi

export CMAKE_BUILD_PARALLEL_LEVEL="$PARALLEL_WORKERS"

cd "$WORKSPACE_DIR"
colcon build \
  --symlink-install \
  --packages-up-to jackal_nav2 \
  --allow-overriding ouster_ros \
  --parallel-workers "$PARALLEL_WORKERS" \
  --cmake-args \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs \
    -DBUILD_TESTING=OFF \
    -DBUILD_PCAP=OFF \
    -DBUILD_OSF=OFF \
    -DBUILD_VIZ=OFF \
    -DBUILD_EXAMPLES=OFF \
    '-DCMAKE_CXX_FLAGS=-Wl,--allow-shlib-undefined'

set +u
source "$WORKSPACE_DIR/install/setup.bash"
set -u
echo "Built the external Jackal autonomy workspace at $WORKSPACE_DIR"
