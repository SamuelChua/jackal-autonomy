#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
ML_PYTHON=/home/dcist/ros_venv/bin/python
if [ ! -x "$ML_PYTHON" ]; then
  echo "Run jackal-build inside the research container (missing $ML_PYTHON)."
  exit 2
fi
if [ ! -f "$WORKSPACE_DIR/src/spine-multi/pyproject.toml" ]; then
  echo "Missing SPINE source; initialize the pinned research submodules on the host."
  exit 2
fi
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

# Dependencies are supplied by the image; do not resolve or upgrade them here.
"$ML_PYTHON" -m pip install --no-deps --no-build-isolation -e "$WORKSPACE_DIR/src/spine-multi"

export CMAKE_BUILD_PARALLEL_LEVEL="$PARALLEL_WORKERS"

cd "$WORKSPACE_DIR"
/usr/bin/colcon build \
  --metas "$WORKSPACE_DIR/colcon.meta" \
  --symlink-install \
  --allow-overriding ouster_ros \
  --parallel-workers "$PARALLEL_WORKERS" \
  --cmake-args \
    -DCMAKE_BUILD_TYPE=Release \
    -DPython3_EXECUTABLE=/usr/bin/python3 \
    -DPYTHON_EXECUTABLE=/usr/bin/python3 \
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
echo "Built the unified Jackal autonomy and serial workspace at $WORKSPACE_DIR"
