#!/bin/bash
# =============================================================================
# RunPod Training Script
# Copy-paste this on RunPod after SSH-ing in.
#
# Usage:
#   bash runpod_train.sh [TASK_NAME]
#
# Examples:
#   bash runpod_train.sh candy_handover
#   bash runpod_train.sh tissue_box
# =============================================================================

TASK_NAME=${1:-candy_handover}
HF_USER=B04a01361

echo "=== RunPod Training: $TASK_NAME ==="
echo "  Dataset: ${HF_USER}/act_${TASK_NAME}"
echo "  Policy:  ${HF_USER}/act_${TASK_NAME}_policy"

# --- Setup (run once) ---
pip install lerobot wandb
apt-get update && apt-get install -y ffmpeg

# --- Login ---
# huggingface-cli login
# wandb login

# --- Train ---
lerobot-train \
  --dataset.repo_id=${HF_USER}/act_${TASK_NAME} \
  --policy.type=act \
  --output_dir=outputs/train/act_${TASK_NAME} \
  --job_name=act_${TASK_NAME} \
  --policy.device=cuda \
  --policy.repo_id=${HF_USER}/act_${TASK_NAME}_policy \
  --wandb.enable=true
