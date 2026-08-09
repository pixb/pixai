#!/bin/bash
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-3B-Instruct-AWQ \
  --quantization awq_marlin \
  --gpu-memory-utilization 0.8 \
  --max-model-len 16000 \
  --enable-auto-tool-choice \
  --tool-call-parser hermes \
  --port 8765 \
  --host 0.0.0.0
