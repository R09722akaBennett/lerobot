#!/usr/bin/env zsh
# =============================================================================
# Bennett's LeRobot Helper Script
# Usage:
#   ./lerobot.sh record [TASK_NAME] [NUM_EPISODES]
#   ./lerobot.sh eval [TASK_NAME] [POLICY_NAME]
#   ./lerobot.sh train [TASK_NAME]           # local (MPS)
#   ./lerobot.sh train [TASK_NAME] --gpu     # for RunPod (CUDA)
#   ./lerobot.sh teleop
#   ./lerobot.sh find-port
#   ./lerobot.sh find-cameras
#
# Examples:
#   ./lerobot.sh record candy_handover 50
#   ./lerobot.sh eval candy_handover
#   ./lerobot.sh train candy_handover
#   ./lerobot.sh teleop
# =============================================================================

set -e

# --- Load environment ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f .venv/bin/activate ]; then
  source .venv/bin/activate
fi

if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# --- Config ---
FOLLOWER_PORT=${FOLLOWER_PORT:-/dev/tty.usbmodem5B140335481}
LEADER_PORT=${LEADER_PORT:-/dev/tty.usbmodem5B141137431}
CAMERA_INDEX=${CAMERA_INDEX:-0}
CAMERA_WIDTH=${CAMERA_WIDTH:-640}
CAMERA_HEIGHT=${CAMERA_HEIGHT:-480}
CAMERA_FPS=${CAMERA_FPS:-30}

CAMERA_CONFIG="{ front: {type: opencv, index_or_path: $CAMERA_INDEX, width: $CAMERA_WIDTH, height: $CAMERA_HEIGHT, fps: $CAMERA_FPS}}"

# --- Task description lookup ---
get_task_desc() {
  case $1 in
    tissue_box)      echo "Pick up the tissue and place it in the box" ;;
    candy_handover)  echo "Pick up candy from box and place it on the open hand" ;;
    pick_candy)      echo "Pick up candy from box and place it on the open hand" ;;
    grab_tissue)     echo "Grab tissue" ;;
    *)               echo "$1" ;;
  esac
}

# --- Functions ---
usage() {
  echo "Usage:"
  echo "  ./lerobot.sh record [TASK_NAME] [NUM_EPISODES]"
  echo "  ./lerobot.sh eval [TASK_NAME] [POLICY_NAME]"
  echo "  ./lerobot.sh train [TASK_NAME] [--gpu]"
  echo "  ./lerobot.sh teleop"
  echo "  ./lerobot.sh find-port"
  echo "  ./lerobot.sh find-cameras"
  echo ""
  echo "Available tasks:"
  echo "  tissue_box      -> Pick up the tissue and place it in the box"
  echo "  candy_handover  -> Pick up candy from box and place it on the open hand"
  echo "  grab_tissue     -> Grab tissue"
  echo "  (or any custom name — it will be used as both task name and description)"
  exit 1
}

do_record() {
  local TASK_NAME=${1:-candy_handover}
  local NUM_EPISODES=${2:-50}
  local TASK_DESC="$(get_task_desc $TASK_NAME)"

  echo "=== Recording: $TASK_NAME ==="
  echo "  Task: $TASK_DESC"
  echo "  Episodes: $NUM_EPISODES"
  echo "  Camera: index=$CAMERA_INDEX ${CAMERA_WIDTH}x${CAMERA_HEIGHT}@${CAMERA_FPS}fps"
  echo ""

  lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --robot.cameras="$CAMERA_CONFIG" \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/act_${TASK_NAME} \
    --dataset.num_episodes=$NUM_EPISODES \
    --dataset.single_task="$TASK_DESC" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2
}

do_eval() {
  local TASK_NAME=${1:-candy_handover}
  local POLICY_NAME=${2:-act_${TASK_NAME}_policy}
  local TASK_DESC="$(get_task_desc $TASK_NAME)"

  echo "=== Evaluating: $TASK_NAME ==="
  echo "  Policy: ${HF_USER}/$POLICY_NAME"
  echo ""

  lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --robot.cameras="$CAMERA_CONFIG" \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/eval_${TASK_NAME} \
    --dataset.num_episodes=10 \
    --dataset.single_task="$TASK_DESC" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    --policy.path=${HF_USER}/$POLICY_NAME
}

do_train() {
  local TASK_NAME=${1:-candy_handover}
  local DEVICE="mps"

  if [ "$2" = "--gpu" ]; then
    DEVICE="cuda"
  fi

  echo "=== Training: $TASK_NAME ==="
  echo "  Dataset: ${HF_USER}/act_${TASK_NAME}"
  echo "  Device: $DEVICE"
  echo ""

  lerobot-train \
    --dataset.repo_id=${HF_USER}/act_${TASK_NAME} \
    --policy.type=act \
    --output_dir=outputs/train/act_${TASK_NAME} \
    --job_name=act_${TASK_NAME} \
    --policy.device=$DEVICE \
    --policy.repo_id=${HF_USER}/act_${TASK_NAME}_policy \
    --wandb.enable=true
}

do_teleop() {
  echo "=== Teleoperate ==="
  lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader
}

# --- Main ---
COMMAND=${1:-help}
if [ $# -gt 0 ]; then
  shift
fi

case $COMMAND in
  record)     do_record "$@" ;;
  eval)       do_eval "$@" ;;
  train)      do_train "$@" ;;
  teleop)     do_teleop ;;
  find-port)  lerobot-find-port ;;
  find-cameras) lerobot-find-cameras ;;
  *)          usage ;;
esac
