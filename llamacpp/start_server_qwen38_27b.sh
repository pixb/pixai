#!/bin/bash
# Qwen3.8-27B 启动脚本 - TurboQuant MTP 版 (128K 上下文, 视觉 + 投机解码)
# 使用 llama-cpp-turboquant-mtp/ (最新 fork fca3093, 支持 draft-mtp)
# 不依赖旧 b9082 build (无法加载 MTP 版 GGUF)

SERVER="./llama-cpp-turboquant-mtp/build/bin/llama-server"
MODEL="./models/Qwen3.8-27B-Q3_K_M.gguf"
MMPROJ="./models/mmproj-BF16.gguf"
PORT=8080

export LD_LIBRARY_PATH="$(cd "$(dirname "$SERVER")" && pwd):/opt/cuda/lib64:$LD_LIBRARY_PATH"

CPU_THREADS=12
GPU_LAYERS=99
# CONTEXT_SIZE=131072
CONTEXT_SIZE=200000
BATCH_SIZE=512

echo "Starting Qwen3.8-27B (TurboQuant MTP) with 128K context..."
${SERVER} \
  -m "${MODEL}" \
  --mmproj "${MMPROJ}" \
  -c ${CONTEXT_SIZE} \
  -n -1 \
  -t ${CPU_THREADS} \
  -ngl ${GPU_LAYERS} \
  --parallel 1 \
  --cache-type-k turbo3 \
  --cache-type-v turbo3 \
  --flash-attn on \
  --load-mode mlock \
  --batch-size ${BATCH_SIZE} \
  --ubatch-size 512 \
  --reasoning-budget 0 \
  --spec-type draft-mtp \
  --spec-draft-n-max 3 \
  --spec-draft-p-min 0.75 \
  --host 0.0.0.0 \
  --port ${PORT} \
  --log-disable \
  &
echo "Server started on http://localhost:${PORT}"
echo "MMPROJ vision enabled, MTP speculative decoding enabled"

