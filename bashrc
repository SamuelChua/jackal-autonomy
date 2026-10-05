# Host-editable shell configuration sourced after the image defaults.
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-2}"
export HF_HOME="${HF_HOME:-/home/dcist/data/weights/huggingface}"
export TORCH_HOME="${TORCH_HOME:-/home/dcist/data/weights/torch}"
export TIKTOKEN_CACHE_DIR="${TIKTOKEN_CACHE_DIR:-/home/dcist/data/weights/tiktoken}"
export SPINE_LLM_BASE_URL="${SPINE_LLM_BASE_URL:-http://172.20.129.12:11434/v1}"
export SPINE_LLM_MODEL="${SPINE_LLM_MODEL:-qwen3-coder:30b}"
export SPINE_LLM_API_KEY="${SPINE_LLM_API_KEY:-ollama}"
export SPINE_LLM_MAX_TOKENS="${SPINE_LLM_MAX_TOKENS:-8192}"
export SPINE_LLM_TIMEOUT_S="${SPINE_LLM_TIMEOUT_S:-60}"
export SPINE_LLM_REASONING_EFFORT="${SPINE_LLM_REASONING_EFFORT:-none}"
export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_AUTOMATIC_DISCOVERY_RANGE:-LOCALHOST}"
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
