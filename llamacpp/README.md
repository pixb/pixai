# llama.cpp API Server 示例

基于 llama.cpp 构建的本地 LLM API Server，支持 OpenAI-compatible API 格式。

## llama.cpp 源码管理

本项目的 `llama.cpp-src/` 是外部克隆的依赖，不纳入版本控制。

### 克隆

```bash
git clone https://github.com/ggml-org/llama.cpp.git llamacpp/llama.cpp-src
```

### 修改 & 编译

```bash
cd llamacpp

# 编译 (CPU)
mkdir -p build && cd build
cmake ../llama.cpp-src -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(nproc)

# 或编译 (AMD GPU / ROCm)
# 注意：ROCm 7.2 + Arch Linux 上 HIP 编译有已知问题，见 amdgpurun.md
mkdir -p build && cd build
HIPCXX=/opt/rocm/lib/llvm/bin/clang HIP_PATH=/opt/rocm \
cmake ../llama.cpp-src -DGGML_HIP=ON -DGPU_TARGETS=gfx902 -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(nproc)

# 安装 (可选)
cmake --install . --prefix ~/.local
```

### 同步上游更新

```bash
cd llamacpp/llama.cpp-src
git remote add upstream https://github.com/ggml-org/llama.cpp.git  # 首次添加
git fetch upstream
git checkout main
git merge upstream/main
# 重新编译 (回到 llamacpp 目录)
cd ../build && cmake --build . --config Release -j$(nproc)
```

## 环境

- **GPU**: AMD Radeon Vega 8 Graphics (gfx902, 无独立显存)
- **模式**: CPU 推理
- **模型**: Qwen2.5-1.5B-Instruct (Q4_K_M 量化，约 1GB)

## 目录结构

```
llamacpp/
├── llama.cpp-src/     # llama.cpp 源码
├── build/             # 编译产物
│   └── bin/
│       └── llama-server  # API Server 可执行文件
├── models/            # 模型文件目录
├── download_model.sh  # 下载模型脚本
├── start_server.sh    # 启动服务脚本
├── test_server.sh     # 测试脚本
└── README.md
```

## 下载模型

### 方式一：使用 Python huggingface_hub

```bash
cd models
python3 -c "
from huggingface_hub import hf_hub_download

path = hf_hub_download(
    repo_id='Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    filename='qwen2.5-1.5b-instruct-q4_k_m.gguf',
    local_dir='.'
)
print(f'Downloaded: {path}')
"
```

### 方式二：使用 curl (hf-mirror)

```bash
cd models
curl -L -o qwen2.5-1.5b-instruct-q4_k_m.gguf \
  'https://hf-mirror.com/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf'
```

### 可用模型参考

| 模型 | 仓库 | 文件名 | 大小 | 速度参考 |
|------|------|--------|------|----------|
| Qwen2.5-1.5B | Qwen/Qwen2.5-1.5B-Instruct-GGUF | qwen2.5-1.5b-instruct-q4_k_m.gguf | 1.1GB | ~19 tok/s |
| Qwen2.5-3B | Qwen/Qwen2.5-3B-Instruct-GGUF | qwen2.5-3b-instruct-q4_k_m.gguf | 2.0GB | ~11 tok/s |

> 注意: 7B 以上模型会被分成多个分片文件，需要分别下载并合并

> [!INFO] amd核显运行
> [amdgpurun](./amdgpurun.md)
> 1.5b 12.6 tok/s

## 启动 API Server

### 启动 1.5B 模型

```bash
./build/bin/llama-server \
  -m ./models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
  -c 2048 -n 512 -t 4 \
  --host 0.0.0.0 --port 8080 \
  --log-disable &
```

### 启动 3B 模型

```bash
./build/bin/llama-server \
  -m ./models/qwen2.5-3b-instruct-q4_k_m.gguf \
  -c 2048 -n 512 -t 4 \
  --host 0.0.0.0 --port 8080 \
  --log-disable &
```

> 模型加载需要 10-30 秒，请耐心等待

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 模型文件路径 | 必填 |
| `-c` | Context 大小 | 2048 |
| `-n` | 最大生成长度 | 512 |
| `-t` | CPU 线程数 | 4 |
| `--port` | 服务端口 | 8080 |
| `--host` | 监听地址 | 0.0.0.0 |

服务启动后访问: <http://localhost:8080/docs> 查看 API 文档

## 测试

```bash
# 非代理请求 (如果系统有代理)
curl --noproxy '*' http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'

# 或使用项目脚本
./test_server.sh
```

## API 使用

### OpenAI-Compatible 端点

```bash
# 非流式输出
curl --noproxy '*' http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'

# 流式输出
curl --noproxy '*' http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### Embeddings

```bash
curl --noproxy '*' http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": "The quick brown fox jumps over the lazy dog"
  }'
```

## 与 Python 集成

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="qwen2.5-1.5b-instruct-q4_k_m.gguf",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    temperature=0.7,
    max_tokens=512
)

print(response.choices[0].message.content)
```

## 常用命令

```bash
# 停止服务
pkill -f llama-server

# 查看帮助
./build/bin/llama-server --help

# 指定 GPU (如果有 NVIDIA GPU)
# ./build/bin/llama-server -mg 0 ...

# 查看后台进程输出
tail -f nohup.out
```
