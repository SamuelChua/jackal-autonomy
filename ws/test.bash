#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"

set +u
source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "$WORKSPACE_DIR/install/setup.bash"
set -u

cd "$WORKSPACE_DIR"
colcon test \
  --packages-select jackal_nav2 \
  --event-handlers console_direct+
colcon test-result --verbose

ros2 launch jackal_nav2 jackal_sensors.launch.py --show-args >/dev/null
ros2 launch jackal_nav2 jackal_navigation.launch.py --show-args >/dev/null
ros2 launch jackal_nav2 record_jackal.launch.py --show-args >/dev/null
ros2 launch jackal_launch jackal_serial.launch.py --show-args >/dev/null

if [ "${RMW_IMPLEMENTATION:-}" != "rmw_fastrtps_cpp" ]; then
  echo "ERROR: Expected Fast DDS (rmw_fastrtps_cpp), found: ${RMW_IMPLEMENTATION:-unset}"
  exit 1
fi

python - <<'PY'
from importlib.metadata import version

import cv2
import matplotlib
from mpl_toolkits.mplot3d import Axes3D
import numpy
import torch
import ultralytics
import yaml

print(f"torch={torch.__version__}, cuda_wheel={torch.version.cuda}")
print(f"torch_cuda_available={torch.cuda.is_available()}")
print(f"ultralytics={version('ultralytics')}")
print(f"opencv={cv2.__version__}")
print(f"numpy={numpy.__version__}")
print(f"matplotlib={matplotlib.__version__}")
print(f"axes3d={Axes3D.__name__}")
print(f"pyyaml={yaml.__version__}")
PY

echo "Jackal autonomy workspace tests passed."
