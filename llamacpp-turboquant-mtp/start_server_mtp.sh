#!/bin/bash
# atomic-llama-cpp-turboquant: MTP + TurboQuant3 启动脚本
# Qwen3.6-27B NextN Speculative Decoding

SERVER="./llama-cpp-turboquant/build/bin/llama-server"
MODEL="./models/Qwen3.6-27B-UDT-Q4_K_XL_MTP.gguf"
PORT=8080

export LD_LIBRARY_PATH="./llama-cpp-turboquant/build/bin:/opt/cuda/lib64:$LD_LIBRARY_PATH"

echo "=== atomic-llama-cpp-turboquant ==="
echo "Model: $MODEL"
echo "Mode:  MTP (NextN) + TurboQuant3 KV"
echo "Port:  $PORT"
echo ""

${SERVER} \
    -m  "${MODEL}" \
    -md "${MODEL}" \
    --spec-type nextn \
    --draft-max 2 \
    --draft-min 1 \
    -c 8192 \
    -ngl 99 \
    -ngld 99 \
    -ctk turbo3 \
    -ctv turbo3 \
    -fa on \
    --host 0.0.0.0 \
    --port ${PORT} \
    &
echo "Server started on http://localhost:${PORT}"
