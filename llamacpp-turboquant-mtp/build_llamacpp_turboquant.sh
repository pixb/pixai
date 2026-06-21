#!/bin/bash
# 编译 llama-cpp-turboquant（依赖 init.sh 已准备好的环境）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 检测 CUDA 工具链
CUDA_ROOT=""
if command -v /opt/cuda/bin/nvcc &>/dev/null; then
  CUDA_ROOT="/opt/cuda"
  echo ">>> 使用 CUDA: $CUDA_ROOT ($(/opt/cuda/bin/nvcc --version | grep release))"
elif command -v nvcc &>/dev/null; then
  CUDA_ROOT="$(dirname "$(dirname "$(which nvcc)")")"
  echo ">>> 使用 CUDA: $CUDA_ROOT"
else
  echo ">>> 未找到 CUDA 工具链，降级为 CPU 编译"
fi

# 编译
echo ""
echo "=== 编译 llama-cpp-turboquant ==="
BUILD_DIR="$SCRIPT_DIR/llama-cpp-turboquant/build"
mkdir -p "$BUILD_DIR"

CMAKE_OPTS=("-DCMAKE_BUILD_TYPE=Release")

if [ -n "$CUDA_ROOT" ]; then
  CMAKE_OPTS+=(
    "-DCUDAToolkit_ROOT=$CUDA_ROOT"
    "-DCMAKE_CUDA_COMPILER=$CUDA_ROOT/bin/nvcc"
    "-DGGML_CUDA=ON"
    "-DGGML_CUDA_FA=ON"
    "-DGGML_CUDA_GRAPHS=ON"
  )
fi

cmake -S "$SCRIPT_DIR/llama-cpp-turboquant" -B "$BUILD_DIR" "${CMAKE_OPTS[@]}"
cmake --build "$BUILD_DIR" --config Release -j "$(nproc)"

echo ""
echo ">>> 编译完成: $BUILD_DIR/bin/llama-server"
echo ">>> 启动: ./start_server_turboquant_128k.sh"
