#!/bin/bash
# Qwen3.8-27B-UD-IQ1_S 启动脚本 - 笔记本 (WSL2 + RTX 4070 Laptop 8GB) [TurboQuant turbo3]
# 使用 TheTom/llama-cpp-turboquant fork (tag b10465-fca3093, 支持 turbo3 3.5-bit KV cache)
# turbo3 目标: 同样 ~8GB 显存把上下文从 16K 提到 ~48-64K (q8_0 只能到 ~28K)

SERVER="./llama-cpp-turboquant-mtp/build/bin/llama-server"
MODEL="./models/Qwen3.8-27B-UD-IQ1_S.gguf"
PORT=8081

export LD_LIBRARY_PATH="$(cd "$(dirname "$SERVER")" && pwd):/opt/cuda/lib64:$LD_LIBRARY_PATH"

# 上下文: turbo3 下可提到 49152/65536, 实测后按余量调整
CONTEXT_SIZE=${CTX:-49152}
BATCH_SIZE=512

# 防死循环采样 (IQ1_S 必配):
#   --reasoning off       关闭思考层(IQ1_S 思考是死循环主因, 且打断后不输出正文)
#   --temperature 1.2     高于默认 0.8 避开复读阈值
#   --min-p 0.05          过滤低概率噪声
#   --repeat-last-n 512   惩罚窗口 512 (默认 64 太短)
#   --repeat-penalty 1.35 主动惩罚已生成 token 的复读
echo "Starting Qwen3.8-27B-UD-IQ1_S (RTX 4070 Laptop, TurboQuant turbo3) with ${CONTEXT_SIZE} ctx..."

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
  --cache-type-k turbo3 \
  --cache-type-v turbo3 \
  --flash-attn on \
  --batch-size ${BATCH_SIZE} \
  --ubatch-size 512 \
  --host 0.0.0.0 \
  --port ${PORT}