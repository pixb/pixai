#!/bin/bash
# Start llama.cpp API Server

SERVER="./build/bin/llama-server"
MODEL="./models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
PORT=8080
CTX_SIZE=2048
N_PREDICT=512
N_THREADS=4

echo "Starting llama.cpp API Server..."
echo "Model: ${MODEL}"
echo "Port: ${PORT}"
echo ""

${SERVER} \
    -m "${MODEL}" \
    -c ${CTX_SIZE} \
    -n ${N_PREDICT} \
    -t ${N_THREADS} \
    --host 0.0.0.0 \
    --port ${PORT} \
    --log-disable \
    &

echo "Server started on http://localhost:${PORT}"
echo "API docs: http://localhost:${PORT}/docs"
echo ""
echo "Example curl request:"
echo 'curl http://localhost:'"${PORT}"'/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}"'
