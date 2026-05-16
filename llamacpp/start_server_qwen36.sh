#!/bin/bash
# 启动 Qwen3.6-27B 模型服务

SERVER="./build/bin/llama-server"
MODEL="./models/Qwen3.6-27B-Q4_K_M.gguf"
PORT=8080

echo "Starting llama.cpp API Server..."
echo "Model: ${MODEL}"
echo "Port: ${PORT}"
echo ""

${SERVER} \
    -m "${MODEL}" \
    -c 81920 \
    -n 512 \
    -t 4 \
    -ngl 99 \
    --parallel 1 \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --flash-attn on \
    --mlock \
    --reasoning-budget 0 \
    --host 0.0.0.0 \
    --port ${PORT} \
    --log-disable \
    &

echo "Server started on http://localhost:${PORT}"
echo "API docs: http://localhost:${PORT}/docs"