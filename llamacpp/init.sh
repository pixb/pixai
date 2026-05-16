#!/bin/bash
# 初始化 llama.cpp 环境（仅准备，不编译）

set -e

echo "=== 初始化 llama.cpp 环境 ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 检测系统
if [ -f /etc/arch-release ]; then
  SYSTEM="archlinux"
elif [ -f /etc/debian_version ]; then
  SYSTEM="ubuntu"
else
  SYSTEM="unknown"
fi
echo ">>> 检测到系统: $SYSTEM"

# ---- 系统依赖 ----
echo ""
echo "=== 安装系统依赖 ==="

install_arch_deps() {
  local missing=()
  for pkg in base-devel cmake git; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      missing+=("$pkg")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo ">>> 安装: ${missing[*]}"
    sudo pacman -S --noconfirm "${missing[@]}"
  else
    echo ">>> 基础依赖已安装"
  fi
}

install_ubuntu_deps() {
  sudo apt update
  sudo apt install -y build-essential cmake git
}

if [ "$SYSTEM" = "archlinux" ]; then
  install_arch_deps
elif [ "$SYSTEM" = "ubuntu" ]; then
  install_ubuntu_deps
fi

# ---- NVIDIA 驱动 + CUDA ----
echo ""
echo "=== NVIDIA 驱动与 CUDA ==="

if lspci | grep -qi "nvidia"; then
  echo ">>> 检测到 NVIDIA GPU（硬件存在）"

  if ! command -v nvidia-smi &>/dev/null; then
    echo ">>> 安装 NVIDIA 驱动..."
    if [ "$SYSTEM" = "archlinux" ]; then
      sudo pacman -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
    elif [ "$SYSTEM" = "ubuntu" ]; then
      sudo apt install -y nvidia-driver-545
    fi
    echo ">>> 驱动已安装，请重启系统后继续"
    exit 0
  fi

  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  echo ">>> GPU: $GPU_NAME"

  if ! command -v nvcc &>/dev/null; then
    echo ">>> 安装 CUDA Toolkit..."
    if [ "$SYSTEM" = "archlinux" ]; then
      sudo pacman -S --noconfirm cuda
    elif [ "$SYSTEM" = "ubuntu" ]; then
      sudo apt install -y nvidia-cuda-toolkit
    fi
  else
    echo ">>> CUDA Toolkit 已安装"
  fi
else
  echo ">>> 未检测到 NVIDIA GPU"
fi

# ---- 模型目录 ----
echo ""
echo "=== 创建模型目录 ==="
mkdir -p models
echo ">>> $SCRIPT_DIR/models"

# ---- pyenv ----
echo ""
echo "=== 配置 pyenv ==="
PYTHON_VERSION="3.14.4"

if ! pyenv versions --bare 2>/dev/null | grep -qx "$PYTHON_VERSION"; then
  echo ">>> 安装 Python $PYTHON_VERSION（耗时较长）..."
  pyenv install "$PYTHON_VERSION"
fi

pyenv local "$PYTHON_VERSION"
echo ">>> Python: $PYTHON_VERSION"

# ---- Python 依赖 ----
echo ""
echo "=== 安装 Python 依赖 ==="
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi
pip install requests

echo ""
echo "=== 初始化完成 ==="
echo ""
echo "下一步："
echo "  编译:  ./build_llamacpp.sh"
echo "  下载:  ./download_model.sh"
echo "  启动:  ./start_server.sh"