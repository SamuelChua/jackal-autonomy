# Unified Jackal Autonomy and Serial Project Context

## Status at handoff

The autonomy and low-level Jackal serial stacks are now integrated in one ROS 2
Jazzy workspace and one `kumarrobotics/jackal_autonomy:latest` image. The final
validated image is:

```text
sha256:f61b67b9c910fa450e035d5ab164a02ffd5b4d74ebe7a09f13263d0ab52a25d4
```

No Git commit or push was made. The user intends to review and commit the outer
repository and the `jackal_serial` submodule changes. Do not delete or retag
other Docker images, containers, files, or build cache.

The repository is `/home/dcist/Docker/autonomy_ws`. Preserve the user's earlier
untracked `run_personal.bash`; all other listed changes belong to this integration.

## Source and submodule state

- The real `KumarRobotics/jackal-serial` repository is a submodule at
  `ws/src/jackal_serial`, tracking remote `main` at
  `b75e3f9044da2181b6f281105e5a48c62f625ea9` before the local integration
  changes. It is intentionally dirty and uncommitted.
- `.gitmodules` uses `git@github.com:KumarRobotics/jackal-serial.git`.
- The temporary implementation under `/home/dcist/Docker/final_ws` was used only
  as a behavioral reference; its files were not copied into this repository.
- The submodule remains one repository containing six ROS packages. Colcon
  discovers them recursively, so packages no longer need to be copied or built
  one by one.

## Implemented integration

### Unified image and build

- `Dockerfile` now installs the Jackal serial/control dependencies alongside the
  autonomy dependencies, including LibSerial, ZeroMQ/cppzmq, serial_driver/asio,
  Joy, xacro, LMS1xx, robot_state_publisher, controller manager, hardware
  interface, diff-drive controller, and joint-state broadcaster.
- `ros-jazzy-rmw-fastrtps-cpp` is installed and
  `RMW_IMPLEMENTATION=rmw_fastrtps_cpp` is the image default. The serial bringup
  no longer starts a Zenoh router.
- `ws/build.bash` runs dependency installation and one colcon command for the
  entire mounted workspace. The completed build successfully built 14 packages.
- `ws/test.bash` also checks the serial launch arguments and the Fast DDS default.
- Existing Torch/Ultralytics, Matplotlib isolation, Grid Map RViz, GPU, and
  host-only Git credential behavior remains intact.

### Controller ABI mismatch and fix

The first controller smoke exposed an ABI-incoherent inherited ROS installation:
the base image contained older ABI-coupled `ros2_control` and
`diagnostic_updater` libraries, while current Jazzy controller packages were
being installed in the child. Mixing provider and consumer binaries caused the
controller-manager/plugin load failure; this was not a Jackal launch-file or
hardware-device problem.

The image now upgrades the coupled set together:

- `ros-jazzy-controller-interface`
- `ros-jazzy-controller-manager`
- `ros-jazzy-controller-manager-msgs`
- `ros-jazzy-diagnostic-updater`
- `ros-jazzy-diff-drive-controller`
- `ros-jazzy-hardware-interface`
- `ros-jazzy-joint-limits`
- `ros-jazzy-joint-state-broadcaster`

Build-time symbol checks verify that `libdiagnostic_updater.so` exports, and
`libcontroller_manager.so` consumes, the same
`diagnostic_updater::Updater` constructor ABI. After this coherent upgrade the
controller manager loaded and both controllers activated successfully.

### Jackal serial repository changes

- Added `jackal-launch/launch/jackal_serial.launch.py` as the main ROS launch
  entry point. It composes serial, robot-state-publisher, teleop, and optional
  Jeti nodes, and launches ros2_control, Linux Joy, and both controller spawners.
- Launch arguments include `namespace`, `serial_device`, `serial_baud`,
  `start_serial`, `start_control`, `start_robot_state_publisher`,
  `start_teleop`, `start_linux_joy`, and `start_jeti`.
- The legacy shell entrypoint now finds and sources the unified or legacy
  workspace, defaults to Fast DDS, and `exec`s the new launch. It does not run
  Zenoh or use a startup sleep.
- Package manifests now declare the missing system, ROS, launch, and internal
  runtime dependencies. `io_context` was added to the Jeti target.
- GTest discovery was moved under `BUILD_TESTS`, so a normal production build no
  longer requires GTest unconditionally.
- The submodule README documents one-workspace build, Fast DDS bringup, launch
  arguments, and no-motion validation.

### Runtime and documentation changes

- `run.bash` now checks for both required source trees and maps the host `video`
  GID in addition to input/device access. The first validation container omitted
  that GID and could not open ZED; the corrected container opened it successfully.
- `data/configs/zed2i.yaml` disables `depth.depth_stabilization` and
  `pos_tracking.pos_tracking_enabled`. DLIO supplies robot odometry, and disabling
  the unused ZED tracking module prevents its synchronous startup from blocking
  camera and IMU publication.
- The root README documents the unified source closure, single colcon build,
  Fast DDS, serial alias, and separate serial/sensor/navigation launches. Safe
  validation commands are retained in this project context instead.
- Existing default image/tag selection remains in place. `run.bash` no longer
  synchronizes the workspace; run `sync_workspace.bash` manually when needed.
- Keep the untracked `run_personal.bash` synchronized one-to-one with `run.bash`
  whenever `run.bash` changes. Its only intentional differences are the
  `HOST_CODEX_DIR` variable and the bind mount from the host `~/.codex` directory
  to `/home/dcist/.codex` in the container; preserve those Codex-specific lines.

## Completed validation

- Rebuilt only `kumarrobotics/jackal_autonomy:latest`; the final image ID is the
  `f61b67...` image shown above.
- One workspace build completed successfully for all 14 packages.
- The complete test suite passed: 26 tests plus launch-argument and runtime
  checks.
- A controller-only smoke test loaded controller manager and successfully
  configured and activated `jackal_velocity_controller` and
  `joint_state_broadcaster` after the ABI fix.
- Hardware serial validation against the real `/dev/jackal` reached all three
  acceptance milestones:

  ```text
  [SERIAL] Connected to Jackal
  [SERIAL] Writing Time Sync Packet
  Loaded node '/jackal_serial_node' in container '/jackal/PlatformComposition'
  ```

- Live sensor validation showed Ouster point clouds near 10 Hz, Ouster IMU near
  100 Hz, and DLIO actively consuming/publishing.
- ZED detected and opened after the video GID correction. With redundant visual
  odometry disabled, live RGB measured about 15.08 Hz and ZED IMU measured about
  100 Hz.
- Navigation launched successfully and its managed Nav2 nodes reached the active
  lifecycle state.

## Validation safety conditions

- All validation used `ROS_DOMAIN_ID=232` to isolate the test graph.
- No navigation goal, goal pose, waypoint, or action request was issued.
- Serial hardware validation disabled teleop, Linux Joy, Jeti, and ros2_control
  command production as appropriate.
- Controller smoke disabled the serial hardware path and all teleoperation/Joy/
  Jeti inputs while testing controller activation.
- Navigation validation disabled the Joy command bridge and did not request
  motion. No drive command or navigation goal was issued.

## Safe no-motion validation procedure

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

## Deferred serial and control issues

These were present in the upstream/reference serial implementation and were not
required for the requested startup milestone:

1. Serial success currently proves that `/dev/jackal` opened and the time-sync
   write returned; response reads, acknowledgement, feedback, and deserialization
   are still absent/commented out. Add a board handshake, read loop, diagnostics,
   reconnect behavior, and explicit write/read failure reporting.
2. `SerialCore` accepts a baud parameter but currently selects 115200 internally.
   Map supported parameter values to LibSerial baud enums or reject unsupported
   values clearly.
3. Joint-state conversion assumes at least four velocity entries in a fixed
   `[left, right, left, right]` order. Resolve velocities by joint name, validate
   sizes and finite values, and fail safe on malformed messages.
4. The Jeti component emits four axes with a mapping incompatible with
   `JackalTeleop`, while teleop indexes axis 4 without bounds checks. Define one
   documented Joy mapping, validate array sizes, and add component tests before
   enabling Jeti on hardware.
5. The retained `joy_filter` source forces its e-stop button field off. Remove
   that override or replace it with an explicit, reviewed safety policy; the new
   main launch does not need this filter.
6. Teleop initially publishes a zero-stamped `TwistStamped`. Stamp every command
   at publication time and define command-source timeout/arbitration behavior.
7. The current ros2_control model uses `mock_components/GenericSystem` to turn
   controller output into joint states for serial serialization; it is not a
   physical feedback hardware interface. A future design should expose actual
   board state through a ros2_control hardware plugin or clearly document the
   open-loop architecture.
8. Clean up the controller YAML's deprecated limit fields and the stray quote in
   the secondary controller `type` value, and reconcile the manager update-rate
   documentation with the runtime configuration.

## Observed warnings and proposed follow-up

- **Controller RT FIFO warning:** controller manager could not enable FIFO
  scheduling. If deterministic control timing is required, add the smallest
  necessary `SYS_NICE` capability and rtprio/memlock limits, confirm host kernel
  support, and then re-test; do not expand privilege without measuring the need.
- **Deprecated jerk-limit parameters:** Jazzy warns that `has_jerk_limits` is
  deprecated. Update `control.yaml` to the current diff-drive limit schema and
  represent disabled jerk limits with the supported NAN/unset values.
- **Nav inflation warning:** review the configured robot footprint, inscribed/
  circumscribed radii, inflation radius, and cost-scaling settings together.
  Revalidate both costmaps before changing clearances; do not reduce inflation
  merely to silence the warning.
- **Nav/TF startup timing warnings:** transient transform timing/extrapolation
  messages were observed while the live sensor/DLIO/Nav2 graph came up. Capture a
  timestamped bag if they persist after startup, verify Ouster/DLIO clock and
  frame stamps, inspect the complete `map -> odom -> base_link` chain, and adjust
  launch sequencing or transform tolerances only from measured latency.

## Files with integration changes

Outer repository changes include `.gitmodules`, `Dockerfile`, `README.md`,
`bashrc`, `data/configs/zed2i.yaml`, `run.bash`, `ws/build.bash`, `ws/test.bash`,
`docs/PROJECT_CONTEXT.md`, and the `ws/src/jackal_serial` gitlink. The submodule
contains the new launch file plus entrypoint, README,
manifest, CMake dependency, and GTest-gating changes described above. Review and
commit the submodule first, then record its new gitlink in the outer repository;
do not push until the user is satisfied with the hardware behavior.
