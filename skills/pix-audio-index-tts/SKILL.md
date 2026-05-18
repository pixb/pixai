---
name: pix-audio-index-tts
description: This skill should be used when the user asks to convert text to speech, generate audio, create TTS voice, or do voice synthesis. Activates with phrases like 语音合成, TTS, 文字转语音, 生成语音, 配音, 朗读. Provides text formatting, text splitting, TTS generation, and audio merging workflow.
---

# pix-audio-index-tts

## 基础信息

| 属性 | 值 |
| :--- | :--- |
| **名称** | pix-audio-index-tts |
| **版本** | 1.0.0 |
| **类型** | 简单技能 |
| **核心功能** | 将文本转换为语音，包括文本格式化、分片、生成、合并的完整工作流 |
| **适用环境** | Trae / opencode |

## 核心目标

将非标准化的书面文本转换为适合 TTS 模型朗读的口语脚本，并通过 IndexTTS MCP 生成自然流畅的语音输出。

## 使用方法

### 激活方式

当用户请求以下内容时，skill 会自动激活：

- 语音合成、TTS、文字转语音
- 生成语音、配音、朗读
- 将文本转为音频、把文字读出来

### 执行步骤 (TODO List)

当 AI 执行任务时，按以下步骤进行，并在每步完成后向用户汇报进度：

- [ ] 1. **文本格式化** - 调用 `format_tts_text()` 格式化输入文本
- [ ] 2. **文本分片** - 调用 `text_split()` 拆分成片段 ⚠️ **默认 max_length=100**
- [ ] 3. **语音生成** - 循环调用 `tts_generate()` 生成每个片段
- [ ] 4. **音频合并** - 调用 `audio_merge()` 合并所有片段
- [ ] 5. **返回结果** - 返回下载链接或文件路径

> 💡 **重要提示**: 文本分片默认每个片段最大 100 字符。对于长文本，会自动拆分为多个片段分别生成，最后合并。如需调整，可通过 `max_length` 参数修改。

### 工作流程

```
1. 文本格式化 → 2. 文本分片 → 3. 语音生成 → 4. 音频合并 → 5. 返回结果
```

## 功能说明

### 1. 文本格式化 (format_tts_text)

将书面文本转换为口语化表达：

| 规则 | 示例 | 处理结果 |
|------|------|----------|
| 数字+单位 | `2022 年`, `100 %` | `2022年`, `100%` |
| 日期格式 | `2023-10-01` | `2023年10月1日` |
| 时间格式 | `12:30` | `12点30分` |
| 特殊符号 | `&`, `@`, `#` | `和`, `在`, 去除 |
| Markdown | `**加粗**`, `## 标题` | 去除符号 |
| URL | `https://...` | 去除 |
| 多音字 | `行长` | `银行行长` |

### 2. 文本分片 (text_split)

将长文本拆分为适合 TTS 处理的短片段，智能断句。

### 3. 语音生成 (tts_generate)

使用参考音频生成语音，支持参数覆盖。

### 4. 音频合并 (audio_merge)

将多个音频片段合并为一个完整音频。

## MCP 工具

| 工具名 | 功能 | 耗时操作 | 返回 |
|--------|------|----------|------|
| `text_split` | 文本分片 | - | JSON (chunks) |
| `reference_list` | 列出参考音频 | - | JSON (data) |
| `tts_generate` | 语音生成 | ✓ | JSON + `download_url` |
| `audio_merge` | 音频合并 | - | JSON + `download_url` |

## 工作流封装

### text_to_speech()

```python
async def text_to_speech(
    text: str,
    reference_name: str = "liuyandong3",
    output_dir: str = "output",
    language: str = "Auto",
    emo_alpha: float = None,
    temperature: float = None,
    emo_text: str = None,
    use_emo_text: bool = False,
    max_length: int = 100,  # ⚠️ 默认每个片段最大 100 字符
) -> dict:
    """将文本转换为语音的完整工作流"""
    # 1. 文本格式化
    formatted_text = format_tts_text(text)
    
    # 2. 文本分片
    split_result = await text_split(formatted_text, max_length=max_length)
    chunks = split_result.get("chunks", [])
    
    if not chunks:
        return {"success": False, "error": "文本分片失败"}
    
    # 3. 语音生成
    audio_files = []
    download_url = None
    for i, chunk in enumerate(chunks):
        result = await tts_generate(
            text=chunk,
            reference_name=reference_name,
            ref_text="",  # 会自动从参考音频获取默认值
            language=language,
            emo_alpha=emo_alpha,
            temperature=temperature,
            emo_text=emo_text,
            use_emo_text=use_emo_text,
            output_dir=output_dir,
        )
        if result.get("success"):
            audio_files.append(result["file_path"])
            download_url = result.get("download_url")  # 最后一个片段的 URL
    
    if not audio_files:
        return {"success": False, "error": "语音生成失败"}
    
    # 单片段直接返回，多片段合并
    if len(audio_files) == 1:
        return result  # tts_generate 已包含 download_url
    
    # 4. 音频合并
    merged = await audio_merge(files=audio_files, output_dir=output_dir)
    
    return merged
```

### format_tts_text()

```python
def format_tts_text(text: str) -> str:
    """格式化文本为适合 TTS 朗读的口语化脚本"""
    import re
    
    # 1. 数字与单位连接
    text = re.sub(r'(\d+)\s*([年日月时分秒公斤千克克米厘米毫米%])', r'\1\2', text)
    text = re.sub(r'(\d+)\s*([0-9]+)', r'\1\2', text)
    
    # 2. 日期与时间标准化
    text = re.sub(r'(\d{4})-(\d{1,2})-(\d{1,2})', r'\1年\2月\3日', text)
    text = re.sub(r'(\d{1,2}):(\d{2})', r'\1点\2分', text)
    
    # 3. 特殊符号处理
    text = text.replace('&', '和').replace('@', '在')
    text = re.sub(r'[#*~]', '', text)
    
    # 4. 去除 Markdown 格式
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
    text = re.sub(r'#+\s*', '', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    
    # 5. 去除 URL
    text = re.sub(r'https?://[^\s]+', '', text)
    
    # 6. 去除注脚
    text = re.sub(r'\[\d+\]', '', text)
    text = re.sub(r'\(注[：:]?[^)]*\)', '', text)
    
    return text.strip()
```

## 使用示例

### 示例 1: 简单文本转语音

```
用户: "将这段文字生成语音：今天天气真好，适合出去散步。"

AI 执行步骤:
- [x] 1. 文本格式化 → "今天天气真好，适合出去散步。"
- [x] 2. 文本分片 → ["今天天气真好，适合出去散步。"]
- [x] 3. 语音生成 → "output/tts_123.wav"
- [x] 4. 音频合并 → (单片段跳过合并)
- [x] 5. 返回结果 → "语音已生成: http://localhost:8002/audio/tts_123.wav"
```

### 示例 2: 长文本转语音

```
用户: "将这篇文档生成语音并保存到 /tmp/audio 目录"

AI 执行步骤:
- [x] 1. 文本格式化 → 格式化后的文本
- [x] 2. 文本分片 → ["片段1", "片段2", "片段3"] (3个片段)
- [x] 3. 语音生成 → output/1.wav, 2.wav, 3.wav
- [x] 4. 音频合并 → "/tmp/audio/merged.wav"
- [x] 5. 返回结果 → "语音已保存到 /tmp/audio/merged.wav"
```

### 示例 3: 自定义语音参数

```
用户: "用更快更活泼的语音风格生成这段文字"

AI 执行步骤:
- [x] 1. 文本格式化
- [x] 2. 文本分片
- [x] 3. 语音生成 (emo_alpha=0.8)
- [x] 4. 音频合并
- [x] 5. 返回结果
```

## 最佳实践

1. **参考音频选择**: 使用 `reference_list` 先查看可用的参考音频，选择最符合场景的
2. **⚠️ 文本长度控制 (重要)**: 
   - **默认 `max_length=100`**，每个片段最多 100 字符
   - 长文本会自动拆分为多个片段，分别生成后合并
   - 如需调整片段大小，修改 `max_length` 参数 (建议范围: 50-200)
3. **参数调优**:
   - `emo_alpha`: 情感强度，值越大情感越丰富
   - `temperature`: 采样温度，值越大随机性越高
   - `emo_text`: 情感描述文本，描述期望的情感风格
4. **批量处理**: 大量文本可分批处理，避免超时
5. **错误处理**: 始终检查每步的 `success` 字段，确保流程正常
6. **服务状态检查**: 每次调用 TTS 接口前检查服务状态
7. **返回结果**: 优先使用 `download_url` 直接下载音频，无需手动拼接 URL

## 服务启动说明

### 正常启动

#### TTS 服务（必需）
- **服务地址**: http://localhost:8002（局域网可访问需替换为实际 IP）
- **启动命令**: 
  ```bash
  bash /Volumes/data/dev/code/ai/index-tts-api/start.sh &
  ```
  或
  ```bash
  uv run uvicorn src.index_tts_api.main:app --host 0.0.0.0 --port 8002
  ```
- **健康检查**: `curl http://localhost:8002/health`

#### MCP 服务（本地 stdio，自动通过 MCP 配置启动）
无需手动启动，opencode 配置中声明 `command` 即可。

#### MCP 服务（局域网远程访问）
如需在其他机器通过 MCP 访问：
```bash
TTS_BASE_URL=http://<本机局域网IP>:8002 uv run python start_mcp_http.py --host 0.0.0.0 --port 9330 &
```

### 调用前检查流程

每次调用 TTS 接口前，按以下步骤检查服务状态：

```python
import httpx
import subprocess
import time

async def check_and_start_service():
    """检查服务状态，必要时启动服务"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://localhost:8002/health", 
                timeout=3.0
            )
            if response.status_code != 200:
                raise Exception("Service not healthy")
            print("✓ TTS service is running")
            return True
    except Exception as e:
        print(f"⚠ Service not available: {e}")
        print("Starting TTS service...")
        
        # 启动服务（后台运行）
        subprocess.Popen(
            ["bash", "/Volumes/data/dev/code/ai/index-tts-api/start.sh"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        
        # 等待服务启动
        for i in range(20):
            await asyncio.sleep(2)
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.get(
                        "http://localhost:8002/health", 
                        timeout=3.0
                    )
                    if response.status_code == 200:
                        print(f"✓ Service started successfully (waited {i*2}s)")
                        return True
            except:
                pass
        
        raise Exception("Failed to start TTS service")
```

### 错误处理流程

如果在调用 TTS 接口时遇到以下错误：
- HTTP 500 错误
- `meta tensor` 错误
- 连接失败

说明服务可能已崩溃退出。下次调用前检查会发现服务已停止，自动启动。

## 注意事项

- 需要先启动 TTS 服务：`bash /Volumes/data/dev/code/ai/index-tts-api/start.sh &`
- 需要配置 MCP Server 到 opencode（参考 `trae_mcp.json.demo`）
- `tts_generate` 为耗时操作，MCP 超时设置为 20 分钟
- 音频生成后保存在 `output` 目录，通过 `download_url` 即可下载
- 远程使用时确保 `TTS_BASE_URL` 设置为局域网可访问的 IP
