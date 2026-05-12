#!/bin/bash
# 初始化 llama.cpp 环境

set -e

echo "=== 初始化 llama.cpp 环境 ==="
echo ""

# 检测系统
if [ -f /etc/arch-release ]; then
    SYSTEM="archlinux"
elif [ -f /etc/debian_version ]; then
    SYSTEM="ubuntu"
else
    SYSTEM="unknown"
fi

echo ">>> 检测到系统: $SYSTEM"

# 检查 GPU
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    echo ">>> 检测到 GPU: $GPU_NAME"

    # 检查是否需要安装 CUDA Toolkit
    if ! command -v nvcc &> /dev/null; then
        echo ">>> nvcc 未找到，正在安装 CUDA Toolkit..."
        if [ "$SYSTEM" = "archlinux" ]; then
            sudo pacman -S --noconfirm cuda
        elif [ "$SYSTEM" = "ubuntu" ]; then
            sudo apt update && sudo apt install -y nvidia-cuda-toolkit
        else
            echo ">>> 无法自动安装 CUDA Toolkit，请手动安装"
            exit 1
        fi
        export PATH=/usr/local/cuda/bin:$PATH
    else
        echo ">>> CUDA Toolkit 已安装"
    fi
    USE_CUDA=1
else
    echo ">>> 未检测到 NVIDIA GPU，使用 CPU 模式"
    USE_CUDA=0
fi

# 检查 llama.cpp 源码
if [ ! -d "llama.cpp-src" ]; then
    echo ">>> 克隆 llama.cpp 源码..."
    git clone https://github.com/ggml-org/llama.cpp.git llama.cpp-src
else
    echo ">>> llama.cpp-src 已存在"
fi

# 创建 models 目录并下载模型
echo ""
echo ">>> 下载模型..."
mkdir -p models

if [ -f "models/qwen2.5-1.5b-instruct-q4_k_m.gguf" ]; then
    echo ">>> 模型文件已存在"
else
    echo ">>> 下载 Qwen2.5-1.5B 模型..."
    curl -L -o models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
        'https://hf-mirror.com/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf'
fi

# 编译
echo ""
echo ">>> 编译 llama-server..."
if [ ! -d "build" ]; then
    mkdir -p build
fi
cd build

# 清理旧配置
rm -rf CMakeCache.txt CMakeFiles

if [ "$USE_CUDA" = "1" ]; then
    echo ">>> 使用 CUDA 加速编译..."
    cmake ../llama.cpp-src -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
else
    echo ">>> 使用 CPU 编译..."
    cmake ../llama.cpp-src -DCMAKE_BUILD_TYPE=Release
fi

cmake --build . --config Release -j$(nproc)
cd ..

echo ""
echo "=== 初始化完成 ==="
echo "运行 ./start_server.sh 启动服务"