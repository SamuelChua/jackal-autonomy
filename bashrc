# Host-editable shell configuration sourced after the image defaults.
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-2}"
export HF_HOME="${HF_HOME:-/home/dcist/data/weights/huggingface}"
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

if [ -f /home/dcist/dcist_ws/install/setup.bash ]; then
  source /home/dcist/dcist_ws/install/setup.bash
fi

alias jackal-sensors='ros2 launch jackal_nav2 jackal_sensors.launch.py'
alias jackal-navigation='ros2 launch jackal_nav2 jackal_navigation.launch.py'
alias jackal-serial='ros2 launch jackal_launch jackal_serial.launch.py'
alias jackal-record='ros2 launch jackal_nav2 record_jackal.launch.py'
alias jackal-goto='ros2 run jackal_nav2 goto_nav2'
alias jackal-build='/home/dcist/dcist_ws/build.bash'
alias jackal-test='/home/dcist/dcist_ws/test.bash'
