ARG BASE_IMAGE=kumarrobotics/dcist-master-jazzy-nvda:latest
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
USER dcist
WORKDIR /home/dcist

LABEL org.opencontainers.image.title="Jackal Autonomy"
LABEL org.opencontainers.image.description="Unified ROS 2 Jazzy runtime for Jackal autonomy and serial control"
LABEL org.opencontainers.image.base.name="kumarrobotics/dcist-master-jazzy-nvda:latest"

# Runtime/build dependencies for the external autonomy workspace and the
# jackal_serial low-level control stack.
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends --no-upgrade \
        cppzmq-dev \
        libcurl4-openssl-dev \
        libeigen3-dev \
        libjsoncpp-dev \
        libomp-dev \
        libpcl-dev \
        libserial-dev \
        libspdlog-dev \
        libzmq3-dev \
        python3-matplotlib \
        python3-yaml \
        ros-jazzy-ament-cmake-auto \
        ros-jazzy-asio-cmake-module \
        ros-jazzy-backward-ros \
        ros-jazzy-compressed-depth-image-transport \
        ros-jazzy-compressed-image-transport \
        ros-jazzy-controller-manager \
        ros-jazzy-cv-bridge \
        ros-jazzy-diagnostic-updater \
        ros-jazzy-diff-drive-controller \
        ros-jazzy-geographic-msgs \
        ros-jazzy-grid-map-core \
        ros-jazzy-grid-map-cv \
        ros-jazzy-grid-map-msgs \
        ros-jazzy-grid-map-ros \
        ros-jazzy-grid-map-visualization \
        ros-jazzy-hardware-interface \
        ros-jazzy-image-transport \
        ros-jazzy-joint-state-broadcaster \
        ros-jazzy-joy \
        ros-jazzy-lms1xx \
        ros-jazzy-nav2-behaviors \
        ros-jazzy-nav2-bt-navigator \
        ros-jazzy-nav2-common \
        ros-jazzy-nav2-controller \
        ros-jazzy-nav2-costmap-2d \
        ros-jazzy-nav2-lifecycle-manager \
        ros-jazzy-nav2-mppi-controller \
        ros-jazzy-nav2-msgs \
        ros-jazzy-nav2-navfn-planner \
        ros-jazzy-nav2-planner \
        ros-jazzy-nav2-rotation-shim-controller \
        ros-jazzy-nav2-smac-planner \
        ros-jazzy-nav2-smoother \
        ros-jazzy-nav2-velocity-smoother \
        ros-jazzy-nav2-waypoint-follower \
        ros-jazzy-nmea-msgs \
        ros-jazzy-pcl-conversions \
        ros-jazzy-pcl-ros \
        ros-jazzy-point-cloud-transport \
        ros-jazzy-rmw-cyclonedds-cpp \
        ros-jazzy-rmw-fastrtps-cpp \
        ros-jazzy-robot-localization \
        ros-jazzy-robot-state-publisher \
        ros-jazzy-ros2bag \
        ros-jazzy-rosbag2-storage-mcap \
        ros-jazzy-rosidl-default-generators \
        ros-jazzy-serial-driver \
        ros-jazzy-spatio-temporal-voxel-layer \
        ros-jazzy-tf2-eigen \
        ros-jazzy-theora-image-transport \
        ros-jazzy-xacro \
        ros-jazzy-zed-msgs

# Keep the ML environment separate from ROS' system Python. Torch matches the
# known-working CUDA wheel set used by the predecessor image; torchaudio,
# bitsandbytes, and tiktoken are deliberately not installed.
ENV PYTHONNOUSERSITE=1
COPY --chown=dcist:dcist requirements-ml.txt /tmp/jackal-autonomy-requirements.txt
RUN python3 -m venv --system-site-packages /home/dcist/ros_venv \
    && source /home/dcist/ros_venv/bin/activate \
    && python -m pip install --no-cache-dir \
        torch==2.5.1 \
        torchvision==0.20.1 \
        --index-url https://download.pytorch.org/whl/cu121 \
    && python -m pip install --no-cache-dir \
        -r /tmp/jackal-autonomy-requirements.txt
RUN source /home/dcist/ros_venv/bin/activate && python -c 'import cv2, matplotlib, numpy, torch, torchvision, ultralytics, yaml; assert numpy.__version__ == "1.26.4"; assert cv2.__version__ == "4.11.0"; assert torch.__version__ == "2.5.1+cu121"; assert torchvision.__version__ == "0.20.1+cu121"; assert ultralytics.__version__ == "8.4.112"; print("Pinned Python runtime imports passed")'

# Ubuntu's Matplotlib package preloads its older mpl_toolkits namespace.
# Preload the venv copy for both venv and ROS system-Python entry points.
RUN test ! -e /home/dcist/ros_venv/lib/python3.12/site-packages/mpl_toolkits/__init__.py && printf %s '"""Prefer the venv Matplotlib toolkit over the Ubuntu namespace."""' > /home/dcist/ros_venv/lib/python3.12/site-packages/mpl_toolkits/__init__.py && test ! -e /home/dcist/ros_venv/lib/python3.12/site-packages/00-jackal-matplotlib.pth && printf %s 'import mpl_toolkits' > /home/dcist/ros_venv/lib/python3.12/site-packages/00-jackal-matplotlib.pth && test ! -e /usr/local/lib/python3.12/dist-packages/00-jackal-matplotlib.pth && sudo ln -s /home/dcist/ros_venv/lib/python3.12/site-packages/00-jackal-matplotlib.pth /usr/local/lib/python3.12/dist-packages/00-jackal-matplotlib.pth && /home/dcist/ros_venv/bin/python -c 'from mpl_toolkits.mplot3d import Axes3D; print("Venv Matplotlib 3D import passed")' && PYTHONPATH=/home/dcist/ros_venv/lib/python3.12/site-packages /usr/bin/python3 -c 'from mpl_toolkits.mplot3d import Axes3D; print("ROS system-Python Matplotlib 3D import passed")'


# GroundGrid declares this RViz plugin as a runtime dependency. Keep it in the
# image even though headless autonomy launches do not start RViz.
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends --no-upgrade \
        ros-jazzy-grid-map-rviz-plugin
# Align the ABI-coupled diagnostic and ros2_control binaries from the inherited
# image, then verify both the provider and controller-manager consumer symbols.
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends --only-upgrade \
        ros-jazzy-controller-interface \
        ros-jazzy-controller-manager \
        ros-jazzy-controller-manager-msgs \
        ros-jazzy-diagnostic-updater \
        ros-jazzy-diff-drive-controller \
        ros-jazzy-hardware-interface \
        ros-jazzy-joint-limits \
        ros-jazzy-joint-state-broadcaster \
    && nm -D --defined-only /opt/ros/jazzy/lib/libdiagnostic_updater.so | c++filt | grep -E 'diagnostic_updater::Updater::Updater.*double, unsigned char' >/dev/null \
    && nm -D --undefined-only /opt/ros/jazzy/lib/libcontroller_manager.so | c++filt | grep -E 'diagnostic_updater::Updater::Updater.*double, unsigned char' >/dev/null

# Source and Git credentials remain on the host. Only append the shell hooks
# needed by the externally mounted workspace.
RUN printf '%s\n' \
        '' \
        '# Jackal autonomy additions' \
        'source /home/dcist/ros_venv/bin/activate' \
        '[ -f /home/dcist/.bashrc_host ] && source /home/dcist/.bashrc_host' \
        >> /home/dcist/.bashrc

ENV VIRTUAL_ENV=/home/dcist/ros_venv
ENV PATH=/home/dcist/ros_venv/bin:${PATH}
ENV PYTHONPATH=/home/dcist/ros_venv/lib/python3.12/site-packages
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp
