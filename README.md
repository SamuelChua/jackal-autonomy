# Jackal autonomy image

Standalone Docker image and external ROS 2 Jazzy workspace for
[`jackal_nav2`](https://github.com/ankitVP77/jackal_nav2).

The image defaults to `kumarrobotics/jackal_autonomy:latest` and extends the
existing local `kumarrobotics/dcist-master-jazzy-nvda:latest` image as-is. The
base is not rebuilt. No additional application source is cloned or copied into
the derived image; `ws` is populated on the host and bind-mounted over
`/home/dcist/dcist_ws`.

The inherited base may contain its legacy workspace in older layers; the runtime
bind mount hides it, and this child image adds no application source of its own.

## Source closure

The pinned submodules under `ws/src` are the complete source closure of the
current `jackal_nav2/main` launch package:

| Path | Purpose |
| --- | --- |
| `jackal_nav2` | Standalone sensor, navigation, recording, and helper launch package |
| `DLIO` | `direct_lidar_inertial_odometry` |
| `groundgrid` | Ground segmentation and obstacle cloud |
| `ouster-ros` | Ouster driver and messages; recursively includes Ouster SDK |
| `zed-ros2-wrapper` | ZED components and wrapper |

Safety controller, SPINE, MOCHA, teaming/communications, and unrelated semantic
navigation repositories are intentionally not included. The image has
Ultralytics plus its direct inference dependencies for downstream use, but it
does not include bitsandbytes, tiktoken, torchaudio, or the old SPINE/VLM
package set.

## First-time setup

`sync_workspace.bash` performs Git operations on the host and uses
`~/.ssh/id_ed25519_ankit` by default; the key must have mode `600`. The key and
`known_hosts` remain on the host and are never configured, copied, or mounted
inside the container. Set `JACKAL_AUTONOMY_SSH_KEY` to use another host key.

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

The Clearpath platform/hardware driver that consumes the Joy output must be
running separately. `safety_controller` is not used.

## Validation

The current `latest` image is validated with rosdep resolution, a seven-package
Colcon build, all 26 `jackal_nav2` tests, GPU-backed Torch/Ultralytics imports,
an 18-ELF runtime link scan, and an isolated Nav2 lifecycle/plugin startup.
Physical Ouster, ZED, and Jackal hardware were not connected during these tests.

## Configuration

- `-t TAG`, `--tag TAG`: select a tag for `build.bash`, `run.bash`, or `join.bash`; the CLI option overrides image environment variables.
- `JACKAL_AUTONOMY_TAG`: default tag when `--tag` is omitted (default `latest`).
- `JACKAL_AUTONOMY_REPOSITORY`: image repository used with a tag (default `kumarrobotics/jackal_autonomy`).
- `JACKAL_AUTONOMY_IMAGE`: optional full image reference when `--tag` is omitted.
- `BASE_IMAGE`: override the local base tag used by `build.bash`.
- `JACKAL_AUTONOMY_SSH_KEY`: host-only key used by `sync_workspace.bash`; it is never mounted into the container.
- `JACKAL_AUTONOMY_ZED_SETTINGS`: override the offline ZED settings directory.
- `JACKAL_AUTONOMY_SKIP_SYNC=1`: skip the automatic pinned submodule check.
- `JACKAL_AUTONOMY_SYNC_REMOTE=1`: opt into moving submodules to branch heads.
- `JACKAL_AUTONOMY_GPUS`: Docker GPU selector (default `all`).
- `COLCON_PARALLEL_WORKERS`: workspace build concurrency (default `4`).
- `ROS_DOMAIN_ID`: ROS domain selected in `bashrc` (default `2`).
