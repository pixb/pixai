#!/bin/bash
# 编译 llama.cpp（依赖 init.sh 已准备好的环境）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 检测 GPU 是否可用（决定编译选项）
USE_CUDA=0
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
  if command -v nvcc &>/dev/null; then
    USE_CUDA=1
    echo ">>> 启用 CUDA 编译"
  else
    echo ">>> GPU 可用但 nvcc 未找到，尝试 /opt/cuda..."
    export PATH=/opt/cuda/bin:$PATH
    if command -v nvcc &>/dev/null; then
      USE_CUDA=1
      echo ">>> 启用 CUDA 编译（/opt/cuda）"
    fi
  fi
fi

# 克隆源码
echo ""
echo "=== 准备 llama.cpp 源码 ==="
LLAMA_SRC_DIR="$SCRIPT_DIR/llama.cpp-src"
if [ ! -d "$LLAMA_SRC_DIR" ]; then
  echo ">>> 克隆 llama.cpp..."
  git clone --depth 1 --branch b4616 https://github.com/ggerganov/llama.cpp.git "$LLAMA_SRC_DIR"
else
  echo ">>> 源码已存在"
fi

# 编译
echo ""
echo "=== 编译 llama.cpp ==="
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

CMAKE_OPTS=("-DCMAKE_BUILD_TYPE=Release")
[ "$USE_CUDA" -eq 1 ] && CMAKE_OPTS+=("-DLLAMA_CUDA=ON")

cmake -S "$LLAMA_SRC_DIR" -B "$BUILD_DIR" "${CMAKE_OPTS[@]}"
cmake --build "$BUILD_DIR" --config Release -j "$(nproc)"

echo ""
echo ">>> 编译完成: $BUILD_DIR/bin/llama-server"