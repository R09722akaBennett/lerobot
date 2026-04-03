# Bennett's LeRobot Learning Notebook

> Personal notes for learning robot manipulation with LeRobot + SO-101
>
> HF User: `B04a01361`
> Robot IDs: `bennett_follower` / `bennett_leader`
> Started: 2026-04-02

---

## Table of Contents

1. [What is LeRobot?](#1-what-is-lerobot)
2. [Hardware: SO-101](#2-hardware-so-101)
3. [Environment Setup](#3-environment-setup)
4. [Hardware Setup: Motors & Calibration](#4-hardware-setup-motors--calibration)
5. [Teleoperation](#5-teleoperation)
6. [Dataset Recording](#6-dataset-recording)
7. [Dataset Visualization & Replay](#7-dataset-visualization--replay)
8. [Training](#8-training)
9. [Evaluation & Deployment](#9-evaluation--deployment)
10. [Policy Overview](#10-policy-overview)
11. [Deep Dive: ACT Paper](#11-deep-dive-act-paper)
12. [Tips & Best Practices](#12-tips--best-practices)
13. [Learning Log](#13-learning-log)
14. [References](#14-references)

---

## 1. What is LeRobot?

LeRobot is an open-source Python library by Hugging Face for real-world robot learning. It provides the full pipeline:

```
Teleoperate -> Record Dataset -> Train Policy -> Evaluate on Robot
```

Key concepts:
- **Leader arm**: The arm you physically move (teleoperation input device)
- **Follower arm**: The robot arm that mirrors the leader's movement
- **Episode**: One complete demonstration of a task (e.g., pick up object, place it)
- **Policy**: A neural network that learns to imitate your demonstrations
- **Dataset**: A collection of episodes stored on Hugging Face Hub

The repo is a **library** — you don't need to fork it. Your data and trained models are stored on Hugging Face Hub under your account.

---

## 2. Hardware: SO-101

The SO-101 is a 6-axis robotic arm by TheRobotStudio. It uses Feetech STS3215 servo motors.

### Arm Architecture

| Joint | Name | Follower Gear Ratio | Leader Gear Ratio |
|-------|------|-------------------|-----------------|
| 1 | Shoulder Pan | 1/345 | 1/191 |
| 2 | Shoulder Lift | 1/345 | 1/345 |
| 3 | Elbow Flex | 1/345 | 1/191 |
| 4 | Wrist Flex | 1/345 | 1/147 |
| 5 | Wrist Roll | 1/345 | 1/147 |
| 6 | Gripper | 1/345 | 1/147 |

> The leader uses lighter gearing so you can move it easily by hand.

### My Setup

| Component | Port / Index |
|-----------|-------------|
| Follower arm | `/dev/tty.usbmodem5B140335481` |
| Leader arm | `/dev/tty.usbmodem5B141137431` |
| iPhone camera (Continuity) | OpenCV index `0` |
| MacBook built-in camera | OpenCV index `1` |

> Ports may change after reconnecting USB. Always verify with `lerobot-find-port`.

### Calibration Files

```
~/.cache/huggingface/lerobot/calibration/robots/so_follower/bennett_follower.json
~/.cache/huggingface/lerobot/calibration/teleoperators/so_leader/bennett_leader.json
```

---

## 3. Environment Setup

```bash
# 1. Activate virtual environment
source .venv/bin/activate

# 2. Load environment variables (.env contains HF_USER=B04a01361)
export $(cat .env)

# 3. Verify
echo $HF_USER  # -> B04a01361
```

### Shell Variables (set these each session)

```bash
FOLLOWER_PORT=/dev/tty.usbmodem5B140335481
LEADER_PORT=/dev/tty.usbmodem5B141137431
```

### Installation (already done)

```bash
pip install -e ".[feetech]"
```

---

## 4. Hardware Setup: Motors & Calibration

### 4.1 Find USB Ports

```bash
lerobot-find-port
```

Disconnect one arm at a time to identify which port belongs to which arm.

### 4.2 Setup Motors (one-time only)

Each motor needs a unique ID and matching baudrate. Only needed for brand new motors.

**Follower:**
```bash
lerobot-setup-motors \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT
```

**Leader:**
```bash
lerobot-setup-motors \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT
```

Follow the prompts — connect one motor at a time starting from the gripper.

### 4.3 Calibrate (redo after swapping motors or reassembly)

Calibration ensures leader and follower arms have matching position values in the same physical position. This is critical for policies to transfer between robots.

**Follower:**
```bash
lerobot-calibrate \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower
```

**Leader:**
```bash
lerobot-calibrate \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader
```

**Process:**
1. Move all joints to the middle of their range
2. Press Enter
3. Move each joint through its full range of motion

---

## 5. Teleoperation

### 5.1 Basic Teleoperation (no camera)

Use this to test if leader-follower sync works correctly.

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader
```

### 5.2 Find Cameras

```bash
lerobot-find-cameras
```

### 5.3 Teleoperate with Camera

Adds camera visualization via Rerun.

```bash
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 1920, height: 1080, fps: 30}}" \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader \
    --display_data=true
```

---

## 6. Dataset Recording

### 6.1 Hugging Face Auth

```bash
hf auth login --token ${HUGGINGFACE_TOKEN} --add-to-git-credential
```

### 6.2 Record Command

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 1920, height: 1080, fps: 30}}" \
    --teleop.type=so101_leader \
    --teleop.port=$LEADER_PORT \
    --teleop.id=bennett_leader \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/so101_test \
    --dataset.num_episodes=50 \
    --dataset.single_task="Pick up the cube and place it in the bin" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2
```

### 6.3 Keyboard Controls During Recording

| Key | Action |
|-----|--------|
| Right Arrow | End current episode early, move to next |
| Left Arrow | Cancel current episode, re-record it |
| ESC | Stop recording, encode videos, upload |

### 6.4 Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--dataset.episode_time_s` | 60s | Duration per episode |
| `--dataset.reset_time_s` | 60s | Time to reset environment between episodes |
| `--dataset.num_episodes` | 50 | Total episodes to record |
| `--dataset.single_task` | — | Task description (be specific!) |
| `--dataset.video` | true | Save camera as video |
| `--resume` | false | Resume interrupted recording |

### 6.5 Resume Recording (if interrupted)

Add `--resume=true`. Note: `--dataset.num_episodes` = number of **additional** episodes, not total.

```bash
lerobot-record \
    ... \
    --resume=true
```

### 6.6 Dataset Location

- **Local**: `~/.cache/huggingface/lerobot/${HF_USER}/so101_test`
- **Hub**: `https://huggingface.co/datasets/${HF_USER}/so101_test`

### 6.7 Manual Upload

```bash
hf upload ${HF_USER}/record-test ~/.cache/huggingface/lerobot/${HF_USER}/record-test --repo-type dataset
```

### 6.8 Recording Checklist

**Image Quality & Setup:**
- [ ] At least 2 camera views
- [ ] Steady camera (no shaking)
- [ ] Neutral lighting (not yellow/blue)
- [ ] Consistent exposure & focus
- [ ] No leader arm in frame
- [ ] Only moving: follower arm & objects
- [ ] Static/clean background
- [ ] Resolution >= 720p

**Metadata & Protocol:**
- [ ] Correct robot type selected
- [ ] Camera set to ~30 FPS
- [ ] Update metadata if episodes are deleted

**Feature Naming:**
- [ ] Use `<modality>.<location>` convention (e.g. `images.front`, `images.top`)
- [ ] No device-specific names (avoid `images.laptop`, `images.phone`)
- [ ] Wrist cameras: `images.wrist.left`, `images.wrist.right`, etc.

**Task Annotation:**
- [ ] Precise action description (e.g. "Pick yellow block and place in box")
- [ ] 25-50 characters
- [ ] No vague names (no "task1", "demo2")

---

## 7. Dataset Visualization & Replay

### 7.1 Visualize Online

```bash
echo https://huggingface.co/datasets/${HF_USER}/so101_test
```

Paste the URL into: https://huggingface.co/spaces/lerobot/visualize_dataset

### 7.2 Replay an Episode

Replays recorded movements on the physical robot. Useful to verify data quality and repeatability.

```bash
lerobot-replay \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --dataset.repo_id=${HF_USER}/so101_test \
    --dataset.episode=0
```

---

## 8. Training

### 8.1 Train ACT Policy

```bash
lerobot-train \
    --dataset.repo_id=${HF_USER}/so101_test \
    --policy.type=act \
    --output_dir=outputs/train/act_so101_test \
    --job_name=act_so101_test \
    --policy.device=mps \
    --policy.repo_id=${HF_USER}/act_so101_test
```

| Device | Flag |
|--------|------|
| Mac (Apple Silicon) | `--policy.device=mps` |
| NVIDIA GPU | `--policy.device=cuda` |

### 8.2 Enable Weights & Biases (optional)

```bash
wandb login
```

Then add `--wandb.enable=true` to the train command.

### 8.3 Resume Training

```bash
lerobot-train \
    --config_path=outputs/train/act_so101_test/checkpoints/last/pretrained_model/train_config.json \
    --resume=true
```

### 8.4 Upload Checkpoint

```bash
# Latest checkpoint
hf upload ${HF_USER}/act_so101_test \
    outputs/train/act_so101_test/checkpoints/last/pretrained_model

# Specific checkpoint
CKPT=010000
hf upload ${HF_USER}/act_so101_test_${CKPT} \
    outputs/train/act_so101_test/checkpoints/${CKPT}/pretrained_model
```

### 8.5 Train on Google Colab

If your local machine doesn't have a powerful GPU, use the ACT training notebook:
https://huggingface.co/docs/lerobot/notebooks#training-act

---

## 9. Evaluation & Deployment

Run the trained policy on the real robot. This uses `lerobot-record` with a `--policy.path` argument.

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$FOLLOWER_PORT \
    --robot.id=bennett_follower \
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 1920, height: 1080, fps: 30}}" \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/eval_act_so101_test \
    --dataset.single_task="Pick up the cube and place it in the bin" \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    --policy.path=${HF_USER}/act_so101_test
```

The evaluation episodes are saved as a separate dataset (`eval_*`) so you can review success/failure.

---

## 10. Policy Overview

```
Robot Learning
├── Behavioral Cloning (BC) — learn from demonstrations
│   ├── Single-task policies
│   │   ├── ACT              — recommended starter, fast training, ~80M params
│   │   ├── Diffusion Policy — denoising-based action generation
│   │   └── VQ-BET           — vector-quantized behavior transformer
│   └── Generalist policies (pre-trained, fine-tunable)
│       ├── pi0              — vision-language-action model
│       └── SmolVLA          — lightweight VLA model
└── Reinforcement Learning (RL) — learn from rewards
    ├── HIL-SERL             — human-in-the-loop sample-efficient RL
    └── TD-MPC              — temporal difference model predictive control
```

### Which Policy to Start With?

| Policy | Best For | Data Needed | Training Time | Hardware |
|--------|----------|-------------|---------------|----------|
| **ACT** | Beginners, single tasks | 50+ episodes | Hours (1 GPU) | Any GPU / MPS |
| Diffusion | Complex manipulation | 50+ episodes | Hours (1 GPU) | NVIDIA GPU |
| pi0 | Multi-task, generalist | Large datasets | Days (multi-GPU) | High-end GPU |
| SmolVLA | Lightweight generalist | Medium datasets | Hours-Days | GPU |

**Start with ACT.** It's fast, data-efficient, and well-documented.

---

## 11. Deep Dive: ACT Paper

> Notes from Tony Zhao's paper walkthrough: "Learning Fine-Grained Bimanual Manipulation with Low-Cost Hardware"
>
> Paper: https://arxiv.org/abs/2304.13705
> Project page: https://tonyzhaozh.github.io/aloha/

### 11.1 The Core Question

Can learning enable **low-cost, imprecise hardware** to perform fine-grained manipulation tasks?

Fine-grained tasks: inserting a drill bit, slotting RAM into a motherboard, slicing tape with a blade.
Dynamic tasks: balancing/bouncing a ping-pong ball — the world keeps moving whether you pause or not.

Traditional robotics pipelines (perception -> planning -> controls) rely on precise, expensive hardware. Humans don't have industrial-grade proprioception, yet we perform delicate tasks by **learning from closed-loop visual feedback** and actively compensating for errors. This is the inspiration.

### 11.2 Imitation Learning Paradigm

```
Observations (cameras, joint states) --> Neural Network --> Actions
```

**Training time:** A human teleoperates the robot (using leader arms) to perform a task hundreds of times. Record all observations and actions — this is your dataset.

**Test time (inference):** Feed current observations into the trained model, get predicted actions, execute them, repeat.

**Vanilla Behavioral Cloning (BC):** Take one observation snapshot -> predict one action -> execute -> repeat. Simple baseline but has problems (see below).

### 11.3 Problem 1: Multimodality

"Multimodal" here means **multiple valid ways to do the same task**, NOT multimodal inputs.

Example: a robot needs to get past an obstacle. Some demonstrators go left, some go right — both are valid. With a regression loss (MSE/L1/L2), the model learns a **unimodal distribution** and will average the two modes — potentially driving straight into the obstacle.

**Solutions to multimodality:**

| Approach | How it works | Pros | Cons |
|----------|-------------|------|------|
| **Discrete binning** (RT-1) | Discretize action space into bins, use categorical cross-entropy | Can model multi-modal distributions | Precision limited by bin size; no magnitude signal for how far off |
| **Binning + regression** (BeT) | Select a discrete bin, then regress within it | Best of both worlds | More complex |
| **CVAE** (ACT) | Sample latent z from N(0,1), decoder conditions on z + observations | Naturally models multimodality via sampling | Requires tuning; adds training complexity |
| **Diffusion** (Diffusion Policy) | Iteratively denoise a random trajectory | Powerful, general | Slower inference |

### 11.4 How the CVAE Works in ACT

Think of it like generating cat images:
- **VAE Decoder** (used at test time): Takes a sampled latent z + observations -> produces action sequence
- **VAE Encoder** (used at training time only): Takes the ground-truth action sequence + observations -> encodes into latent z

**Training objective** (two parts):
1. **Reconstruction loss:** The decoded action sequence should match the ground-truth
2. **Prior matching loss:** The encoder's output distribution should stay close to N(0,1)

**Why this handles multimodality:** Different sampled z values lead to different action sequences. During training, left-going trajectories get mapped to one region of z-space, right-going to another. At test time, sampling z effectively "chooses" a mode.

**Key insight from Remy (LeRobot maintainer):** The VAE encoder receives the target trajectory as input during training. It encodes the "style" (go left vs go right) into z. At test time, you don't have the target, so you sample z — that's how the model decides.

### 11.5 Problem 2: Compounding Errors

With vanilla BC at 50Hz, a 5-second task = 250 model queries. Small errors at each step push the robot off the data distribution, and errors compound — the robot ends up in states never seen in training and does "crazy things."

**Solution: Action Chunking**

Instead of predicting 1 action, predict **k actions at once** (e.g., 100).

```
t=0:   predict 100 actions, execute all
t=100: predict 100 actions, execute all
t=200: predict 50 actions, done
```

This reduces model queries from 250 to 3, drastically reducing compounding errors.

**Bonus benefit — handles pauses in demonstrations:** If human demonstrators pause for 0.5s (= 25 timesteps at 50Hz), a single-step policy can get "stuck" learning to not move. With action chunking, the pause is contained within a larger chunk that includes movement before and after.

### 11.6 Temporal Ensembling (Optional)

Instead of executing all k actions from one prediction, overlap predictions:

```
t=0: predict 100 actions, execute action[0]
t=1: predict 100 actions, average action[0] with previous action[1], execute
t=2: predict 100 actions, average action[0] with prev action[1] and prev-prev action[2], execute
...
```

Averaging uses **exponential moving average**. Smooths noisy model output.

**Trade-offs:**
- Pro: Smoother trajectories
- Con: Slower reaction time (can't react instantly to changes)
- Con: If different chunks choose different modes, you get mode-averaging again
- Con: Model inference at every step (no speed benefit of chunking)
- Note: **Disabled by default** in the original ACT repo; results are mixed

### 11.7 ACT Architecture

```
Observations:                          VAE Encoder (training only):
  4x Camera images                       Ground-truth action sequence
    -> CNN -> feature tokens               -> Transformer Encoder
  Joint states (14-dim)                    -> latent z ~ N(mu, sigma)
    -> MLP -> token
                                              |
        |                                     v
        v
  [Transformer Encoder]  <----  z (sampled from N(0,1) at test time)
    Self-attention over all
    observation tokens
        |
        v
  [Transformer Decoder]
    Cross-attention with encoder output
        |
        v
  Action sequence (k actions)
```

**Tokenization:**
- Camera images: CNN -> feature map (e.g., 15x10x512) -> each spatial position = one token
- Joint states: 14-dim (6 DoF x 2 arms + 2 grippers) -> MLP -> token

### 11.8 Key Experimental Results

**Baselines compared:**

| Method | Key Feature | Performance |
|--------|------------|-------------|
| Vanilla BC | One obs -> one action, regression loss | Poorest |
| RT-1 | Discrete binning + categorical cross-entropy | Better |
| BeT | Discrete binning + regression within bin + observation history | Even better |
| **ACT** | CVAE + action chunking | **Best by far** |

**Ablation highlights:**

1. **Action chunking helps everyone:** Applying chunking to BC and other baselines also improves them significantly
2. **CVAE matters for human data:** On deterministic scripted data, CVAE has no impact. On human (multimodal) data, CVAE has **huge** impact
3. **Temporal ensembling:** Slight improvement for ACT and BC, but marginal

### 11.9 ACT vs Diffusion Policy — Discussion Notes

From the Q&A session with Remy Cadene (LeRobot maintainer):

- **ACT (CVAE):** Easier to understand, debug, and tune. Even without CVAE it works reasonably well. Good for iteration.
- **Diffusion Policy:** More general, more powerful, easier to tune the generative aspect. Sampling is analogous — ACT samples z at decoder input, Diffusion samples a noisy trajectory and denoises it.
- **Remy's advice:** "Push ACT even without CVAE to its limits first, then move to more powerful modeling with diffusion."
- **Camera setup matters:** 4 cameras was much better than 1 — multiple viewpoints help understand depth and context.
- **Context over complexity:** If you provide past observation frames (history), the model has enough context to stay on one mode without needing a strong generative model.

---

## 12. Tips & Best Practices

### Recording Data
1. **Start simple** — one object, one placement location, one task
2. **50+ episodes minimum** — more data = more robust policy
3. **10 episodes per variation** — if placing at 5 locations, record 10 each
4. **Keep cameras fixed** — don't move between sessions
5. **Be consistent** — same grasping motion, same speed
6. **Object must be visible** — if you can't do the task by looking at camera images alone, the robot can't either
7. **No leader arm in frame** — the policy shouldn't see the leader

### Training
1. **Check loss curves** — use W&B to monitor training progress
2. **Don't overtrain** — if loss plateaus, stop and evaluate
3. **Save checkpoints** — evaluate intermediate checkpoints, not just the final one

### Evaluation
1. **Test 10+ episodes** — single success doesn't mean it works
2. **Same setup as recording** — same camera position, lighting, object placement
3. **Iterate** — if success rate is low, record more data and retrain

---

## 13. Learning Log

### 2026-04-02 — Day 1: Setup & First Recording

**What I did:**
- Set up SO-101 leader and follower arms
- Configured motors and calibrated both arms
- Recorded first dataset: 5 episodes of "Grab tissue" (no video)

**Command used:**
```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=/dev/tty.usbmodem5B140335481 \
    --robot.id=bennett_follower \
    --teleop.type=so101_leader \
    --teleop.port=/dev/tty.usbmodem5B141137431 \
    --teleop.id=bennett_leader \
    --display_data=true \
    --dataset.repo_id=B04a01361/record-test \
    --dataset.num_episodes=5 \
    --dataset.single_task="Grab tissue" \
    --dataset.video=false
```

**Dataset:** `B04a01361/record-test`

**Notes / TODO:**
- [x] Enable video next time (`--dataset.video=true` or remove `--dataset.video=false`)
- [ ] Add a second camera view
- [ ] Record 50+ episodes for real training
- [x] Try training with ACT

---

### 2026-04-03 — Day 2: Camera Setup, Recording, Training & First Eval

**What I did:**
1. Set up iPhone as camera via Continuity Camera (index 0)
2. Fixed macOS camera permissions for OpenCV
3. Recorded 10 episodes with camera: "Pick up the tissue and place it in the box"
4. Trained ACT policy on RunPod (RTX 4090, ~$1.50)
5. Evaluated trained policy on real robot — it worked!

**Camera Setup:**
- iPhone (Continuity Camera): OpenCV index `0`
- MacBook built-in camera: OpenCV index `1`
- Camera permission: System Settings > Privacy & Security > Camera > enable for Terminal

**Recording (with camera):**
```bash
bash record.sh
```
- Dataset: `B04a01361/act_tissue_box_v2` (10 episodes, 1920x1080, 30fps)
- Task: "Pick up the tissue and place it in the box"

**Training on RunPod:**
- GPU: RTX 4090 ($0.59/hr)
- Pod template: RunPod Pytorch 2.4.0
- Had to install ffmpeg: `apt-get update && apt-get install -y ffmpeg`
- Loss plateaued at ~0.067 by step 20K
- Stopped at ~32K steps (loss wasn't improving)
- Total cost: ~$1.50
- wandb: https://wandb.ai/taijinyee95-national-taiwan-university/lerobot/runs/uhe1zots

```bash
pip install lerobot
apt-get update && apt-get install -y ffmpeg
huggingface-cli login
lerobot-train \
  --dataset.repo_id=B04a01361/act_tissue_box_v2 \
  --policy.type=act \
  --output_dir=outputs/train/act_tissue_box_v2 \
  --job_name=act_tissue_box_v2 \
  --policy.device=cuda \
  --policy.repo_id=B04a01361/act_tissue_box_v2_policy \
  --wandb.enable=true
```

**Model:** `B04a01361/act_tissue_box_v2_policy`

**Evaluation:**
```bash
bash eval.sh
```
- Policy ran at ~6-7 Hz (slow due to 1920x1080 on MPS)
- Robot made meaningful movements toward the task
- Reset phase spams warnings (no teleop) — press Right Arrow to skip

**Issues encountered:**
- `--dataset.video=false` without camera = can't train ACT (needs images)
- RunPod: torchcodec needed ffmpeg installed
- Invisible characters in copy-pasted commands break zsh — use shell scripts instead
- MPS OOM with batch_size=8 at 1920x1080 — need batch_size=2 or lower resolution
- USB ports change after reconnection — always run `lerobot-find-port`
- Motor 5 (wrist_roll) occasionally fails communication — power cycle fixes it

**Lessons learned:**
- Camera is required for ACT training on real robots
- Record at 640x480 for faster inference (1920x1080 too slow on Mac MPS)
- Loss plateaus early (~20K steps) — no need to train for 100K
- RunPod RTX 4090 is best value for ACT training (~$1/run)
- Shell scripts (`record.sh`, `eval.sh`, `train.sh`) avoid copy-paste issues
- 10 episodes is enough to see basic learned behavior, but 50+ needed for reliability

**TODO for next session:**
- [ ] Record at 640x480 resolution for faster eval inference
- [ ] Record 50+ episodes for better success rate
- [ ] Add second camera view (MacBook built-in, index 1)
- [ ] Stop RunPod pod
- [ ] Try Diffusion Policy as comparison

---

## 14. References

- LeRobot GitHub: https://github.com/huggingface/lerobot
- LeRobot Docs: https://huggingface.co/docs/lerobot/
- SO-101 Hardware: https://github.com/TheRobotStudio/SO-ARM100
- SO-101 Setup Guide: `docs/source/so101.mdx` (in this repo)
- Imitation Learning Tutorial: `docs/source/il_robots.mdx` (in this repo)
- ACT Policy Docs: `docs/source/act.mdx` (in this repo)
- Dataset Best Practices: https://huggingface.co/blog/lerobot-datasets#what-makes-a-good-dataset
- Discord Community: https://discord.com/invite/s3KuuzsPFb
- ACT Paper: https://arxiv.org/abs/2304.13705
- ACT Project Page: https://tonyzhaozh.github.io/aloha/
- Zihao's LeRobot Notes: https://zihao-ai.feishu.cn/wiki/TS6swApHbinx01kHDi5cf5n5n8c
