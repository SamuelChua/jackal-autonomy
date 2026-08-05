# Jackal autonomy and serial image

Unified Docker image and external ROS 2 Jazzy workspace for:

- [`jackal_nav2`](https://github.com/ankitVP77/jackal_nav2), which provides
  sensors, localization, and navigation.
- [`jackal-serial`](https://github.com/KumarRobotics/jackal-serial), which
  provides low-level serial control, ros2_control, robot description, and RC/
  joystick teleoperation.

The image defaults to `kumarrobotics/jackal_autonomy:latest` and extends the
existing local `kumarrobotics/dcist-master-jazzy-nvda:latest` image as-is. This
base image is not rebuilt. If it is not available locally, refer to the
[`dcist_master_jazzy`](https://github.com/KumarRobotics/dcist_master_ros2)
repository.

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
| `ws/src/jackal_serial` | KumarRobotics Jackal serial repository containing the six low-level control and teleoperation packages |
| `ws/src/DLIO` | `direct_lidar_inertial_odometry` localization |
| `ws/src/groundgrid` | Ground segmentation and obstacle cloud generation |
| `ws/src/ouster-ros` | Ouster driver and messages; recursively includes the Ouster SDK |
| `ws/src/zed-ros2-wrapper` | ZED components and wrapper |

The `jackal_serial` submodule stays as one repository at
`ws/src/jackal_serial`. Colcon recursively discovers its individual ROS
packages; they do not need to be copied or built one by one.

## First-time setup

`sync_workspace.bash` performs Git submodule operations on the host and uses a
validated SSH key by default; the key must have mode `600`. Set
`JACKAL_AUTONOMY_SSH_KEY` to override the key path. The selected key must have
read access to the repositories listed in `.gitmodules`.

```bash
git clone <this-repository-url> jackal_autonomy
cd jackal_autonomy
./sync_workspace.bash
./build.bash
./run.bash
```

Both build and run default to `kumarrobotics/jackal_autonomy:latest`. Builds are
allowed to overwrite that tag. Use the same tag option to build, run, or join a
named variant:

```bash
./build.bash --tag experiment
./run.bash --tag experiment
./join.bash --tag experiment
```

Inside the container, one workspace command installs declared dependencies and
runs one colcon build for both autonomy and low-level control:

```bash
jackal-build
source /home/dcist/dcist_ws/install/setup.bash
jackal-test
```

`run.bash` automatically restores pinned submodules before launch. To advance
each submodule to the head of the branch recorded in `.gitmodules`, use the
explicit update mode and then review and commit the changed gitlinks:

```bash
./sync_workspace.bash --remote
```

## Runtime

The launcher preserves the prior robot-container experience: UID 1000, GPU and
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

Useful aliases inside the container:

```bash
jackal-serial
jackal-sensors
jackal-navigation
jackal-record
jackal-goto /path/to/waypoints.yaml
```

The serial alias launches the low-level stack:

```bash
ros2 launch jackal_launch jackal_serial.launch.py
```

Serial, sensors, and navigation deliberately remain separate processes so each
part can be started and stopped independently:

```bash
ros2 launch jackal_launch jackal_serial.launch.py
ros2 launch jackal_nav2 jackal_sensors.launch.py
ros2 launch jackal_nav2 jackal_navigation.launch.py
```

## Safe no-motion validation

Do not invoke `jackal-goto`, call a Nav2 action, publish a goal pose, or issue
any waypoint/navigation goal during validation.

Start only the physical serial component. Keep ros2_control off because each
`/joint_states` message is converted into a DRIVE packet by the current serial
implementation:

```bash
ros2 launch jackal_launch jackal_serial.launch.py \
  start_control:=false \
  start_robot_state_publisher:=false \
  start_teleop:=false \
  start_linux_joy:=false \
  start_jeti:=false
```

A successful serial connection reaches these messages:

```text
[SERIAL] Connected to Jackal
[SERIAL] Writing Time Sync Packet
Loaded node '/jackal_serial_node' in container '/jackal/PlatformComposition'
```

This milestone proves that the device opened and the time-sync write returned;
the current implementation does not read an acknowledgement from the controller.

Validate ros2_control independently, without opening the physical serial port:

```bash
ros2 launch jackal_launch jackal_serial.launch.py \
  start_serial:=false start_teleop:=false start_linux_joy:=false start_jeti:=false
```

In other terminals, launch sensors normally and navigation with its Joy command
bridge disabled:

```bash
ros2 launch jackal_nav2 jackal_sensors.launch.py
ros2 launch jackal_nav2 jackal_navigation.launch.py start_joy_bridge:=false
```

Together these isolated launches validate sensor, navigation, controller, and
serial startup without connecting a controller output to the physical serial
port, starting teleoperation inputs, translating Nav2 velocity commands into Joy
commands, or sending a navigation goal. Stop each launch with Ctrl-C after the
startup result is collected.
