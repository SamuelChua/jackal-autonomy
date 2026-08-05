# Jackal autonomy image

Standalone Docker image and external ROS 2 Jazzy workspace for
[`jackal_nav2`](https://github.com/ankitVP77/jackal_nav2).

The image defaults to `kumarrobotics/jackal_autonomy:latest` and extends the
existing local `kumarrobotics/dcist-master-jazzy-nvda:latest` image as-is. This is used as a base image and is not rebuilt. If you don't have the initial base image, refer to the  [`dcist_master_jazzy`](https://github.com/KumarRobotics/dcist_master_ros2) repo. No additional application source is cloned or copied into
the derived image; `ws` is populated on the host and bind-mounted over
`/home/dcist/dcist_ws`.

The inherited base may contain its legacy workspace in older layers; the runtime
bind mount hides it, and this child image adds no application source of its own.

## Source closure

The pinned submodules under `ws/src` are the complete source closure of the
current `jackal_nav2/main` launch package:

| Path | Purpose |
| --- | --- |
| `jackal_nav2` | Standalone nav2 autonomy with sensors, navigation, recording, and helper launch package |
| `DLIO` | `direct_lidar_inertial_odometry`- For Localization |
| `groundgrid` | Ground segmentation and obstacle cloud generation |
| `ouster-ros` | Ouster driver and messages; recursively includes Ouster SDK |
| `zed-ros2-wrapper` | ZED components and wrapper |

## First-time setup

`sync_workspace.bash` performs a Git submodules operations on the host and uses
a validated SSH key by default; the key must have mode `600`. Set the `SSH_KEY` variable in the script to use your own validated key. The key you use must have read access to the submodules as detailed in `.gitmodules` file.

```bash
git clone <this-repository-url> jackal_autonomy
cd jackal_autonomy
./sync_workspace.bash
./build.bash
./run.bash
```

Both build and run default to `kumarrobotics/jackal_autonomy:latest`. Builds are
allowed to overwrite an existing tag. Use the same tag option to build, run, or
join a named variant:

```bash
./build.bash --tag experiment
./run.bash --tag experiment
./join.bash --tag experiment
```

Inside the container, build and test the mounted source:

```bash
jackal-build
source /home/dcist/dcist_ws/install/setup.bash
jackal-test
```

`run.bash` automatically restores pinned submodules before launch. To advance
each submodule to the head of the branch recorded in `.gitmodules`, use the
explicit update mode and then review/commit the changed gitlinks:

```bash
./sync_workspace.bash --remote
```

## Runtime

The launcher preserves the prior robot-container experience: UID 1000, GPU and
X11 access, host networking, privileged device access, persistent `data` and
`.ros_docker` mounts, the external workspace, dialout/input groups, and a
host-editable `bashrc`.

The base image's `/etc/clearpath` remains active by default. To replace it with
a robot-specific host configuration, set an explicit directory:

```bash
CLEARPATH_DIR=/path/to/clearpath ./run.bash
```

The tracked `data/configs/zed2i.yaml` is mounted over the ZED wrapper's default
configuration to retain the existing HD2K, 15 Hz, 15 m robot tuning while
keeping the ZED submodule clean.

The tracked `data/configs/usr/local/zed/settings/SN34141806.conf` is also
mounted read-only at `/usr/local/zed/settings` for offline camera calibration.
Set `JACKAL_AUTONOMY_ZED_SETTINGS` to use a different settings directory.

Useful aliases inside the container:

```bash
jackal-sensors
jackal-navigation
jackal-record
jackal-goto /path/to/waypoints.yaml
```

Sensors and navigation deliberately remain separate processes:

```bash
ros2 launch jackal_nav2 jackal_sensors.launch.py
ros2 launch jackal_nav2 jackal_navigation.launch.py
```
