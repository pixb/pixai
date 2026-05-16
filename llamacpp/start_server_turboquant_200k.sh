#!/bin/bash
# TurboQuant 启动脚本 - 200K 上下文版

SERVER="./llama-cpp-turboquant/build/bin/llama-server"
MODEL="./models/Qwen3.6-27B-Q4_K_M.gguf"
PORT=8080

CPU_THREADS=12
GPU_LAYERS=99
CONTEXT_SIZE=200000
BATCH_SIZE=512

echo "Starting TurboQuant with 200K context..."
${SERVER} \
    -m "${MODEL}" \
    -c ${CONTEXT_SIZE} \
    -n 512 \
    -t ${CPU_THREADS} \
    -ngl ${GPU_LAYERS} \
    --parallel 1 \
    --cache-type-k turbo3 \
    --cache-type-v turbo3 \
    --flash-attn on \
    --mlock \
    --batch-size ${BATCH_SIZE} \
    --ubatch-size 512 \
    --reasoning-budget 0 \
    --host 0.0.0.0 \
    --port ${PORT} \
    --log-disable \
    &
echo "Server started"
