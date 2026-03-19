# AMD GPU (ROCm/HIP) 编译记录

## 硬件环境

| 项目 | 值 |
|------|-----|
| GPU | AMD Radeon Vega 8 Graphics |
| 架构 | gfx902 (Picasso) |
| 显存 | 无独立显存，使用系统 RAM 共享 |
| 系统内存 | ~14.5 GB |
| 系统 | Arch Linux |
| ROCm 版本 | 7.2.26043 |

## 已安装的 ROCm 包

```bash
sudo pacman -S --needed \
  rocm-hip-sdk \
  rocm-opencl-runtime \
  rocm-core \
  hip-runtime-amd
```

已配置 `/etc/ld.so.conf.d/rocm.conf` 包含 `/opt/rocm/lib`，并执行 `sudo ldconfig`。

## 编译尝试

### 方式一：使用 HIPCXX + clang（失败）

```bash
cd llamacpp
mkdir -p build && cd build
HIPCXX=/opt/rocm/lib/llvm/bin/clang HIP_PATH=/opt/rocm \
cmake ../llama.cpp-src \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx902 \
  -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j$(nproc)
```

**错误**：`'hip/hip_fp16.h' file not found`

HIP 编译器找不到 ROCm 头文件路径，CMake 的 `CMAKE_HIP_FLAGS` 未生效。

### 方式二：使用 hipcc 作为 C++ 编译器（失败）

```bash
cd llamacpp
rm -rf build && mkdir -p build && cd build
HIP_PATH=/opt/rocm cmake ../llama.cpp-src \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx902 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=/opt/rocm/bin/hipcc \
  -DCMAKE_C_COMPILER=/opt/rocm/bin/hipcc \
  -DCMAKE_CXX_FLAGS="-I/opt/rocm/include" \
  -DCMAKE_EXE_LINKER_FLAGS="-L/opt/rocm/lib -Wl,-rpath,/opt/rocm/lib" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L/opt/rocm/lib -Wl,-rpath,/opt/rocm/lib"
cmake --build . --config Release -j$(nproc)
```

**错误**：`unable to find library -lamdhip64`

链接阶段 `ld.lld` 找不到 `libamdhip64`。虽然 `ldconfig` 已注册 `/opt/rocm/lib`，且 `hipcc` 是二进制而非 shell 脚本，`LD_LIBRARY_PATH` 环境变量对 `hipcc` 内部的链接调用不生效。

## 问题根因

ROCm 7.2 在 Arch Linux 上的安装布局与 llama.cpp 的 HIP CMake 期望不一致：

1. **头文件路径**：HIP 编译器未自动找到 `/opt/rocm/include`，`CMAKE_HIP_FLAGS` 没有正确传递给 HIP 编译步骤
2. **库文件路径**：链接器 `ld.lld` 找不到 `libamdhip64`，hipcc 二进制内部调用 clang++ 时未携带正确的库搜索路径

## 方式三：使用 HIPCXX + clang + 显式路径（成功）

```bash
cd llamacpp
rm -rf build && mkdir -p build && cd build
HIPCXX="/opt/rocm/lib/llvm/bin/clang" HIP_PATH="/opt/rocm" \
cmake ../llama.cpp-src \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx902 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_HIP_FLAGS="-I/opt/rocm/include" \
  -DCMAKE_EXE_LINKER_FLAGS="-L/opt/rocm/lib -Wl,-rpath,/opt/rocm/lib" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L/opt/rocm/lib -Wl,-rpath,/opt/rocm/lib"
cmake --build . --config Release -j$(nproc)
```

**关键点**：
1. `CMAKE_HIP_FLAGS` 添加 ROCm 头文件搜索路径 (`-I/opt/rocm/include`)
2. `CMAKE_EXE_LINKER_FLAGS` 和 `CMAKE_SHARED_LINKER_FLAGS` 添加 ROCm 库搜索路径 (`-L/opt/rocm/lib -Wl,-rpath,/opt/rocm/lib`)
3. 必须显式传递 `--hip-link` 阶段需要的库路径

## 测试结果

### GPU 检测

```
ggml_cuda_init: found 1 ROCm devices (Total VRAM: 7426 MiB):
  Device 0: AMD Radeon Vega 8 Graphics, gfx902:xnack+ (0x902), VMM: no, Wave Size: 64, VRAM: 7426 MiB
```

### 推理测试

```bash
./bin/llama-cli -m ../models/qwen2.5-1.5b-instruct-q4_k_m.gguf -p "Hello, how are you?" -n 50
```

**结果**：
- 模型加载：✅ 成功
- GPU推理：✅ 正常 (Generation: 12.6 t/s)
- 库链接验证：
  - `libggml-hip.so` ✅
  - `libhipblas.so.3` ✅
  - `libamdhip64.so.7` ✅

### Backend Ops 测试

```bash
./bin/test-backend-ops
```

**结果**：
| 测试项 | 状态 |
|--------|------|
| GPU检测 | ✅ AMD Radeon Vega 8 Graphics |
| 基础GPU操作 (ABS等) | ✅ 通过 |
| rocBLAS矩阵运算 | ⚠️ 缺少gfx902 TensileLibrary |

**rocBLAS 限制**：ROCm 7.2 不包含 gfx902 的 TensileLibrary，只有以下架构：
- gfx900, gfx906, gfx908, gfx90a, gfx942
- gfx950, gfx1030, gfx1100-1151, gfx1200, gfx1201

### 结论

- **编译**：✅ 成功
- **GPU推理**：✅ 可用
- **BLAS操作**：⚠️ gfx902过老，依赖CPU回退
- **适用场景**：小模型推理、基础张量运算
- **限制**：大型矩阵运算无法使用GPU加速

## 参考文档

- llama.cpp 官方编译文档：https://github.com/ggerganov/llama.cpp/blob/master/docs/build.md
- ROCm HIP 编译：使用 `HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" cmake ... -DGGML_HIP=ON -DGPU_TARGETS=gfx902`
- 注意：`hipconfig` 不在 PATH 中，需使用 `/opt/rocm/bin/hipconfig`
