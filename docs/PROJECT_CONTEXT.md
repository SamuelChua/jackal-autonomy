# Jackal Autonomy Docker Project Context

## Current goal

Maintain a standalone ROS 2 Jazzy/NVIDIA Docker image for the externally mounted `jackal_nav2` workspace. The current change makes `kumarrobotics/jackal_autonomy:latest` the default, allows intentional tag replacement, adds `--tag` selection to the launcher scripts, and keeps all Git credentials on the host.

## Current workspace state

- The repository is `/home/dcist/Docker/autonomy_ws`.
- Do not delete Docker images, containers, files, or build cache. Only this project image may be rebuilt.
- Do not create a Git commit; the user will commit the changes.
- Pre-existing user changes must be preserved: `bashrc`, changes inside `ws/src/jackal_nav2`, and the untracked `run_personal.bash` with its personal Codex mount.

## Implemented changes

- `build.bash` defaults to `kumarrobotics/jackal_autonomy:latest`, accepts `-t/--tag TAG`, and no longer refuses to replace an existing image tag.
- `run.bash` and `join.bash` use the same default and accept `-t/--tag TAG`.
- `run_personal.bash` has matching tag behavior while retaining its user-specific Codex bind mount.
- `run.bash` and `run_personal.bash` no longer mount an SSH private key, public key, or `known_hosts` into the container.
- `Dockerfile` no longer installs `openssh-client` explicitly or creates `/home/dcist/.ssh/config`. Source and credentials stay on the host.
- `sync_workspace.bash` remains host-only and may use `~/.ssh/id_ed25519_ankit` to synchronize Git submodules before the container starts.
- `README.md` documents the `latest` default, overwrite behavior, tag options, and host-only SSH workflow.

## Earlier dependency fixes retained

- The Python environment contains the Torch/Ultralytics stack required downstream and validates pinned imports during the build.
- The image protects ROS system Python from the virtualenv Matplotlib namespace collision and verifies both import paths.
- `ros-jazzy-grid-map-rviz-plugin` is installed.
- `ros-jazzy-diagnostic-updater` is upgraded and its Nav2-required ABI symbol is checked during the build.

## Validation status

- Shell syntax and CLI help/error behavior passed for the build, run, personal-run, join, sync, workspace-build, and workspace-test scripts.
- Final `git diff --check`, shell syntax, CLI help, image inspection, retained-container inspection, and no-commit checks passed.
- The default image rebuild completed successfully as `kumarrobotics/jackal_autonomy:latest`, image ID `sha256:9ed6ee97f9021ba1465aedd8b7e6c478c56cab0eca510c275af67af65ada2221`.
- Build-time Matplotlib, Grid Map RViz, and `diagnostic_updater` checks passed.
- A GPU-backed runtime smoke test resolved the mounted `jackal_nav2` package, imported the pinned Torch/Ultralytics/OpenCV/NumPy/Matplotlib/PyYAML stack, reported CUDA available, and confirmed that the SSH private key, public key, and SSH config are absent.
- The full `ws/test.bash` suite passed: 26 tests, three launch-file argument checks, and the ML runtime checks.
- The first retained smoke-test container exited early because the test command enabled Bash nounset while sourcing ROS. The corrected test used the same temporary nounset disable as the repository scripts and passed. No containers were removed.

## Remaining work

- No known software blocker remains for this change.
- Physical Ouster, ZED, and Jackal hardware-in-the-loop validation remains optional follow-up work when that hardware is available.
