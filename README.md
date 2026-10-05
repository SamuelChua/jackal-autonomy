# Jackal autonomy image

Unified Docker image and external ROS 2 Jazzy workspace for:

- [`jackal_nav2`](https://github.com/ankitVP77/jackal_nav2), which provides
  sensors, localization, and navigation.
- [`jackal-serial`](https://github.com/KumarRobotics/jackal-serial), which
  provides low-level serial control, ros2_control, robot description, and RC/
  joystick teleoperation.

The BRIDGE build helper defaults to `kumarrobotics/jackal_autonomy:bridge-spine-v1`
and extends the local `dcist-master-jazzy-nvda:bridge-base-b20fac7` image.
The base image must already exist, and its `dcist` UID must match the host user.
The build helper passes the host UID and refuses to overwrite an existing output
tag. Set `BASE_IMAGE` to select another compatible local base.

Application source is not copied into the derived image. The host-populated
`ws` directory is bind-mounted at `/home/dcist/dcist_ws`, so autonomy and
low-level control share one workspace and one container runtime. The inherited
base may contain a legacy workspace in older layers; the runtime bind mount hides
it.

## Source closure

The pinned submodules under `ws/src` provide the complete source closure for the
unified runtime:

| Path | Purpose |
| --- | --- |
| `ws/src/jackal_nav2` | Standalone Nav2 autonomy with sensor, navigation, recording, and helper launch packages |
| `ws/src/jackal_serial` | Jackal serial repository containing the six low-level control and teleoperation packages |
| `ws/src/DLIO` | `direct_lidar_inertial_odometry` localization |
| `ws/src/groundgrid` | Ground segmentation and obstacle cloud generation |
| `ws/src/ouster-ros` | Ouster driver and messages; recursively includes the Ouster SDK |
| `ws/src/zed-ros2-wrapper` | ZED components and wrapper |

The `jackal_serial` submodule stays as one repository at
`ws/src/jackal_serial`. Colcon recursively discovers its individual ROS
packages; they do not need to be copied or built one by one.

## BRIDGE build preparation

The research submodules are pinned in the parent repository:

| Path under `ws/src` | Purpose |
| --- | --- |
| `air_sem_gridmap_interfaces` | Semantic mapping interfaces |
| `air_sem_gridmap` | Semantic grid mapping |
| `air_sem_graph` | Semantic graph |
| `spine-multi` | Planner and ROS executor |
| `vision-ros2` | Visual verification |
| `teaming_msgs` | Shared mission and VLM interfaces |

`requirements-bridge.txt` adds research dependencies to `requirements-ml.txt`.
`constraints-bridge.txt` protects the existing Torch, NumPy, and OpenCV versions.
This is not a complete transitive dependency lock. Docker builds check imports;
model inference and GPU compatibility still require validation in the image.

`ws/colcon.meta` supplements missing package dependencies without changing the
submodules. `ws/build.bash` also installs the separate SPINE Python project into
the image venv in editable mode, without resolving dependencies again.

### On the host: build the dependency image

For the existing checkout and pinned submodules, run as your regular user:

```bash
cd ~/jackal-autonomy
JACKAL_DOCKER_SUDO=1 ./build.bash --tag bridge-spine-v1
```

`JACKAL_DOCKER_SUDO=1` uses sudo only for Docker commands, preserving your UID
and host paths. Omit it if your user already has Docker access. Do not run the
whole helper with sudo. If this output tag already exists, choose a new tag
such as `bridge-spine-v2` and use it consistently below.

### On the host: open the container shell

```bash
cd ~/jackal-autonomy
JACKAL_DOCKER_SUDO=1 ./run.bash --tag bridge-spine-v1
```

### Inside the container: build the mounted ROS workspace

```bash
jackal-build
source /home/dcist/dcist_ws/install/setup.bash
jackal-test
```

The existing `jackal-test` checks the hardware workspace; it does not establish
BRIDGE model or navigation readiness. Opening the shell does not launch nodes.

From another host terminal, join the running container with:

```bash
cd ~/jackal-autonomy
JACKAL_DOCKER_SUDO=1 ./join.bash --tag bridge-spine-v1
```

Model caches persist under host `data/weights`; weights are not included in the
image. Edit the host `bashrc` for planner settings (`SPINE_LLM_*`). The default
planner URL is `http://172.20.129.12:11434/v1`; confirm it is reachable from the
robot. Model downloads and inference still need a separate smoke test.

For a fresh clone, initialize the recorded pins with
`git submodule update --init --recursive`. Avoid `--remote` when reproducing
this deployment. Existing submodule pins are not changed by the build helper.

Before running BRIDGE on hardware, prepare and validate the robot topic/frame
and Nav2 action configuration. The Warty simulation launch files are not a
validated hardware profile. Use one owner for sensors, odometry, TF, GroundGrid,
and Nav2; do not launch duplicate stacks from the research workflow.

## Runtime

The launcher uses the base image’s `dcist` user, verifies its UID against the host,
and provides GPU and
X11 access, host networking, privileged device access, persistent `data` and
`.ros_docker` mounts, the external workspace, dialout/input/video groups, and a
host-editable `bashrc`.

The image and container shell default to Fast DDS:

```bash
echo "$RMW_IMPLEMENTATION"
# rmw_fastrtps_cpp
```

The serial bringup does not start a Zenoh router. Keep all autonomy and serial
processes on the same `ROS_DOMAIN_ID` and `RMW_IMPLEMENTATION`.

The base image's `/etc/clearpath` remains active by default. To replace it with
a robot-specific host configuration, set an explicit directory:

```bash
CLEARPATH_DIR=/path/to/clearpath ./run.bash
```

The tracked `data/configs/zed2i.yaml` is mounted over the ZED wrapper's default
configuration to retain the existing HD2K, 15 Hz, 15 m robot tuning while
keeping the ZED submodule clean. It disables ZED depth stabilization and visual
positional tracking because DLIO is the robot odometry source; this prevents the
unused tracking module from blocking camera and IMU publication.

The tracked `data/configs/usr/local/zed/settings/SN34141806.conf` is also
mounted read-only at `/usr/local/zed/settings` for offline camera calibration.
Set `JACKAL_AUTONOMY_ZED_SETTINGS` to use a different settings directory.

Serial, sensors, and navigation deliberately remain separate processes so each
part can be started and stopped independently:

- Launch the low-level serial, ros2_control, robot-state-publisher, and
  teleoperation stack:

  ```bash
  ros2 launch jackal_launch jackal_serial.launch.py
  ```

  Inside the container, the equivalent convenience alias is `jackal-serial`.

- Launch the Ouster lidar, ZED camera, and DLIO localization stack:

  ```bash
  ros2 launch jackal_nav2 jackal_sensors.launch.py
  ```

  Inside the container, the equivalent convenience alias is `jackal-sensors`.

- Launch GroundGrid obstacle processing, Nav2, static transforms, and the
  navigation command bridge:

  ```bash
  ros2 launch jackal_nav2 jackal_navigation.launch.py
  ```

  Inside the container, the equivalent convenience alias is
  `jackal-navigation`.

- Record a selected profile of autonomy and sensor topics to a rosbag:

  ```bash
  ros2 launch jackal_nav2 record_jackal.launch.py
  ```

  Inside the container, the equivalent convenience alias is `jackal-record`.
  The default recording profile is `navigation`; the other available profiles
  are `lidar`, `semantic`, and `full`.

- Send a sequence of waypoint goals from a YAML file to Nav2:

  ```bash
  ros2 run jackal_nav2 goto_nav2 /path/to/waypoints.yaml
  ```

  Inside the container, the equivalent convenience alias is:

  ```bash
  jackal-goto /path/to/waypoints.yaml
  ```

For example, the three main runtime stacks can be launched independently with:

```bash
jackal-serial
jackal-sensors
jackal-navigation
```
