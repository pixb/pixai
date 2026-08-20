#!/bin/bash
# Qwen3.8-27B-UD-IQ1_S 启动脚本 - 笔记本 (WSL2 + RTX 4070 Laptop 8GB)
# 使用 vanilla llama.cpp 本地编译 (build/bin/llama-server, CUDA sm_89)
# NOTE: 模型为 Unsloth IQ1_S 极限量化 (non-MTP, nextn_predict_layers=0)

SERVER="./build/bin/llama-server"
MODEL="./models/Qwen3.8-27B-UD-IQ1_S.gguf"
PORT=8081

export LD_LIBRARY_PATH="$(cd "$(dirname "$SERVER")" && pwd):/opt/cuda/lib64:$LD_LIBRARY_PATH"

# 上下文: 8GB 显存下实测 16384 可全量offload, 可覆盖
CONTEXT_SIZE=${CTX:-16384}
BATCH_SIZE=512

echo "Starting Qwen3.8-27B-UD-IQ1_S (RTX 4070 Laptop) with ${CONTEXT_SIZE} ctx..."

${SERVER} \
  -m "${MODEL}" \
  --chat-template-file ./Qwen-Fixed-Chat-Templates/chat_template.jinja \
  --reasoning off \
  --temperature 1.2 \
  --min-p 0.05 \
  --repeat-last-n 512 \
  --repeat-penalty 1.35 \
  -c ${CONTEXT_SIZE} \
  -n -1 \
  -t 12 \
  -ngl ${NGL:-99} \
  --parallel 1 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --batch-size ${BATCH_SIZE} \
  --ubatch-size 512 \
  --host 0.0.0.0 \
  --port ${PORT}